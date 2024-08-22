module PS5000A

using Libdl

import PicoScope
import PicoScope.PicoStatus

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




mutable struct Scope
  handle::Int16
  serial::Int8
  resolution::DeviceResolution
end




function open_unit(resolution=DR_8BIT)
  handle = Ref{Int16}(0)
  serial = Ptr{Int8}(0)
  @ccall libps5000a.ps5000aOpenUnit(handle::Ref{Int16}, serial::Ptr{Int8}, resolution::Cint)::PicoStatus
  return Scope(handle.x, Int8(0), DR_8BIT)
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
  ranges .= 0
  length = Ref{Int32}(N)

  ret = @ccall(libps5000a.ps5000aGetChannelInformation(
    scope.handle::Int16,
    CHANNEL_INFO::Cint,
    0::Int32,
    memoryref(ranges)::MemoryRef{Int32},
    length::Ref{Int32},
    Cint(ch)::Cint
  )::PicoStatus
  )

  if ret != PicoScope.OK 
    @info ranges, length
    error("Error while reading channel info: $ret")
  end

  Vector(ranges)[1:length]
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
  enabled::Int16,
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

end
