module PS5000A

using Libdl

import PicoScope
import PicoScope.PicoStatus


export open_unit, close_unit, set_channel, set_data_buffer, set_simple_trigger,
  set_device_resolution, get_values, get_timebase, get_analogue_offset,
  get_device_resolution

if Sys.islinux()
  const libps5000a = find_library("libps5000a")
elseif Sys.isapple()
  const libps5000a = nothing
  error("Apple not supported yet")
elseif Sys.iswindows()
  const libps5000a = find_library("ps5000a")
end

export Scope
export open_unit,
  close_unit,
  ping_unit,
  flash_led,
  get_device_resolution,
  set_device_resolution

const CHANNEL_INFO::Cint = 0

@enum DeviceResolution begin
  DR_8BIT = 0
  DR_12BIT = 1
  DR_14BIT = 2
  DR_15BIT = 3
  DR_16BIT = 4
  DR_10BIT = 10
end

@enum Coupling begin
  AC
  DC
end

@enum Channel begin
  CHANNEL_A
  CHANNEL_B
  CHANNEL_C
  CHANNEL_D
  EXTERNAL
  MAX_CHANNELS = 5
  TRIGGER_AUX
  MAX_TRIGGER_SOURCES
  DIGITAL_PORT0 = 0x80
  DIGITAL_PORT1
  DIGITAL_PORT2
  DIGITAL_PORT3
  PULSE_WIDTH_SOURCE = 0x10000000
end

@enum Range begin
  RANGE_10MV
  RANGE_20MV
  RANGE_50MV
  RANGE_100MV
  RANGE_200MV
  RANGE_500MV
  RANGE_1V
  RANGE_2V
  RANGE_5V
  RANGE_10V
  RANGE_20V
  RANGE_50V
  MAX_RANGES
end

@enum TimeUnits begin
  FS
  PS
  NS
  US
  MS
  S
  MAX_TIME_UNITS
end

@enum ThresholdDirection begin
  ABOVE               = 0
  BELOW               = 1
  RISING              = 2
  FALLING             = 3
  RISING_OR_FALLING   = 4
  ABOVE_LOWER         = 5
  BELOW_LOWER         = 6
  RISING_LOWER        = 7
  FALLING_LOWER       = 8
  POSITIVE_RUNT       = 9
  NEGATIVE_RUNT       = 10
end

const INSIDE = ABOVE
const OUTSIDE = BELOW
const ENTER = RISING
const EXIT = FALLING
const ENTER_OR_EXIT = RISING_OR_FALLING
const NONE = RISING

mutable struct Scope
  handle::Int16
  serial::Int8
  resolution::DeviceResolution
end

get_handle(scope::Scope) = scope.handle




function open_unit(resolution=DR_8BIT)
  handle = Ref{Int16}(0)
  serial = Ptr{Int8}(0)
  @ccall libps5000a.ps5000aOpenUnit(handle::Ref{Int16}, serial::Ptr{Int8}, resolution::Cint)::PicoStatus
  return Scope(handle.x, Int8(0), resolution)
end


function close_unit(scope::Scope)
  @ccall libps5000a.ps5000aCloseUnit(scope.handle::Int16)::PicoStatus
  scope.handle = 0
end


function ping_unit(scope::Scope)
  @ccall libps5000a.ps5000aPingUnit(scope.handle::Int16)::PicoStatus
end


function flash_led(scope::Scope, start)
  @ccall libps5000a.ps5000aFlashLed(scope.handle::Int16, Int16(start)::Int16)::PicoStatus
end


function get_channel_info(scope::Scope, ch::Channel; N=15)
  ranges = Memory{Int32}(undef, N)
  ranges .= -1 
  length = Ref{Int32}(N)

  ret = @ccall(libps5000a.ps5000aGetChannelInformation(
    scope.handle::Int16,
    CHANNEL_INFO::Cint,
    0::Int32,
    memoryref(ranges).ptr_or_offset::Ptr{Int32},
    length::Ref{Int32},
    Cint(ch)::Cint
  )::PicoStatus
  )

  if ret != PicoScope.OK
    @info ranges, length
    error("Error while reading channel info: $ret")
  end

  Range.(filter( x-> x !=-1, Vector(ranges)))
end

function get_device_resolution(scope::Scope)
  resolution = Ref{DeviceResolution}()
  ret = @ccall libps5000a.ps5000aGetDeviceResolution(
    scope.handle::Int16,
    resolution::Ref{DeviceResolution}
  )::PicoStatus
  if ret != PicoScope.OK
    error("Error while reading resolution: $ret")
  end

  return resolution.x

end

function set_device_resolution(scope::Scope, resolution::DeviceResolution)
  ret = @ccall libps5000a.ps5000aSetDeviceResolution(
    scope.handle::Int16,
    Cint(resolution)::Cint
  )::PicoStatus
  if ret != PicoScope.OK
    error("Error while setting resolution: $ret")
  end

  return ret

end


function set_channel(
  scope::Scope,
  channel::Channel,
  enabled,
  coupling::Coupling,
  range::Range,
  offset::Float32=0.0f0)
  @ccall libps5000a.ps5000aSetChannel(
    scope.handle::Int16,
    Cint(channel)::Cint,
    enabled::Int16,
    Cint(coupling)::Cint,
    Cint(range)::Cint,
    offset::Float32
  )::PicoStatus
end

"""
    get_timebase(scope, timebase, num_samples)

Get time base information (sampling rate and max number of samples) for a given
`timebase` value (as used in `run_block` function).
"""
function get_timebase(
  scope::Scope,
  timebase,
  num_samples,
  segment_index=0
)
  time_interval_ns = Ref{Float32}(0.0)
  max_samples = Ref{Int32}(0)

  ret = @ccall libps5000a.ps5000aGetTimebase2(
    scope.handle::Int16,
    timebase::UInt32,
    num_samples::Int32,
    time_interval_ns::Ref{Float32},
    max_samples::Ref{Int32},
    segment_index::UInt32
  )::PicoStatus
  if ret != PicoScope.OK
    error("Error while getting timebase: $ret")
  end
  return (time_interval_ns = time_interval_ns.x, max_samples = max_samples.x)
end


function set_simple_trigger(
  scope::Scope,
  enable,
  source::Channel,
  threshold,
  direction::ThresholdDirection,
  delay=0,
  auto_trigger_ms=0
)
  @ccall libps5000a.ps5000aSetSimpleTrigger(
    scope.handle::Int16,
    enable::Int16,
    Cint(source)::Cint,
    threshold::Int16,
    Cint(direction)::Cint,
    delay::UInt32,
    auto_trigger_ms::Int16
  )::PicoStatus
end


function run_block(
  scope::Scope,
  num_pre_trig_samples,
  num_post_trig_samples,
  timebase,
  segment_index,
  callback=Ptr{Cvoid}(C_NULL),
  parameter=Ptr{Cvoid}(C_NULL),
)
  time_indisposed_ms = Ref{Int32}(0)

  @ccall libps5000a.ps5000aRunBlock(
    scope.handle::Int16,
    num_pre_trig_samples::Int32,
    num_post_trig_samples::Int32,
    timebase::UInt32,
    time_indisposed_ms::Ref{Int32},
    segment_index::UInt32,
    callback::Ptr{Cvoid},
    parameter::Ptr{Cvoid}
  )::PicoStatus
end

function stop(scope)
  @ccall libps5000a.ps5000aStop(scope.handle::Int16)::PicoStatus
end

function is_ready(scope)
  ready = Ref{Int16}(0)

  @ccall libps5000a.ps5000aIsReady(scope.handle::Int16, ready::Ref{Int16})::PicoStatus

  return ready.x != 0
end 

@enum DownsampleMode begin
  RATIO_MODE_NONE         = 0
  RATIO_MODE_AGGREGATE    = 1
  RATIO_MODE_DECIMATE     = 2
  RATIO_MODE_AVERAGE      = 4
  RATIO_MODE_DISTRIBUTION = 8
end

function set_data_buffer(
  scope::Scope,
  source::Channel,
  buffer::Memory{Int16},
  buffer_length,
  segment_index,
  downsample_mode::DownsampleMode
)
  @ccall libps5000a.ps5000aSetDataBuffer(
    scope.handle::Int16,
    Cint(source)::Cint,
    memoryref(buffer).ptr_or_offset::Ptr{Int16},
    buffer_length::Int32,
    Cint(downsample_mode)::Cint,
  )::PicoStatus
end


function get_values(
  scope,
  start_index,
  num_samples,
  downsample_ratio,
  downsample_mode,
  segment_index,
)
  overflow = Ref{Int16}(0)
  num_samples = Ref{UInt32}(num_samples)

  ret = @ccall libps5000a.ps5000aGetValues(
    scope.handle::Int16,
    start_index::UInt32,
    num_samples::Ref{UInt32},
    downsample_ratio::UInt32,
    Cint(downsample_mode)::Cint,
    segment_index::UInt32,
    overflow::Ref{Int16}
  )::PicoStatus

  if ret != PicoScope.OK
    error("Error while reading values: $ret")
  end

  if overflow.x != 0
    @info "Overflow happend" overflow
  end

  return ret

end


function get_minimum_value(scope::Scope)
  value = Ref{Int16}(0)
  @ccall libps5000a.ps5000aMinimumValue(scope.handle::Int16, value::Ref{Int16})::PicoStatus

  return value.x
end

function get_analogue_offset(scope, range, coupling)
  max_voltage = Ref{Float32}(0)
  min_voltage = Ref{Float32}(0)

  ret = @ccall libps5000a.ps5000aGetAnalogueOffset(
    scope.handle::Int16,
    range::Cint,
    coupling::Cint,
    max_voltage::Ref{Float32},
    min_voltage::Ref{Float32}
  )::PicoStatus

  if ret != PicoScope.OK
    error("Error while getting allowed offset range")
  end 

  return (min=min_voltage.x, max=max_voltage.x)

end

end
