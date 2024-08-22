using Libdl

if Sys.islinux()
  const libps5000a = find_library("libps5000a")
elseif Sys.isapple()
  const libps5000a = nothing
  error("Apple not supported yet")
elseif Sys.iswindows()
  const libps5000a = find_library("ps5000a")
end

export PS5000A
export close_unit, flash_led

const PS5000A_CHANNEL_INFO::Cint = 0

@enum PS5000ADeviceResolution begin
  PICO_DR_8BIT = 0
  PICO_DR_12BIT = 1
  PICO_DR_14BIT = 2
  PICO_DR_15BIT = 3
  PICO_DR_16BIT = 4
  PICO_DR_10BIT = 10
end

@enum PS5000ACoupling begin
  PS5000A_AC
  PS5000A_DC
end

@enum PS5000AChannel begin
  PS5000A_CHANNEL_A
  PS5000A_CHANNEL_B
  PS5000A_CHANNEL_C
  PS5000A_CHANNEL_D
  PS5000A_EXTERNAL
  PS5000A_MAX_CHANNELS = 5
  PS5000A_TRIGGER_AUX
  PS5000A_MAX_TRIGGER_SOURCES
  PS5000A_DIGITAL_PORT0 = 0x80
  PS5000A_DIGITAL_PORT1
  PS5000A_DIGITAL_PORT2
  PS5000A_DIGITAL_PORT3
  PS5000A_PULSE_WIDTH_SOURCE = 0x10000000
end

@enum PS5000ARange begin
  PS5000A_10MV
  PS5000A_20MV
  PS5000A_50MV
  PS5000A_100MV
  PS5000A_200MV
  PS5000A_500MV
  PS5000A_1V
  PS5000A_2V
  PS5000A_5V
  PS5000A_10V
  PS5000A_20V
  PS5000A_50V
  PS5000A_MAX_RANGES
end

@enum PS5000ATimeUnits begin
  PS5000A_FS
  PS5000A_PS
  PS5000A_NS
  PS5000A_US
  PS5000A_MS
  PS5000A_S
  PS5000A_MAX_TIME_UNITS
end


@enum PicoStatus::UInt32 begin
  PICO_OK = 0
end


mutable struct PS5000A
  handle::Int16
  serial::Int8
  resolution::PS5000ADeviceResolution
end


library(::PS5000A) = libps5000a


function PS5000A(resolution=PICO_DR_8BIT)
  handle = Ref{Int16}(0)
  serial = Ptr{Int8}(0)
  @ccall libps5000a.ps5000aOpenUnit(handle::Ref{Int16}, serial::Ptr{Int8}, resolution::Cint)::Int32
  return PS5000A(handle.x, Int8(0), PICO_DR_8BIT)
end


function close_unit(scope::PS5000A)
  @ccall libps5000a.ps5000aCloseUnit(scope.handle::Int16)::Int32
  scope.handle = 0
end


function flash_led(scope::PS5000A, start)
  @ccall libps5000a.ps5000aFlashLed(scope.handle::Int16, Int16(start)::Int16)::Int32
end


function get_channel_info(scope::PS5000A, ch::PS5000AChannel; N=15)
  ranges = Memory{Int32}(undef, N)
  ranges .= 0
  length = Ref{Int32}(N)

  ret = @ccall(libps5000a.ps5000aGetChannelInformation(
    scope.handle::Int16,
    PS5000A_CHANNEL_INFO::Cint,
    0::Int32,
    memoryref(ranges)::MemoryRef{Int32},
    length::Ref{Int32},
    Cint(ch)::Cint
  )::Int32
  )

  if ret != 0
    @info ranges, length
    error("Error while reading channel info: $ret")
  end

  Vector(ranges)[1:length]
end

function get_device_resolution(scope::PS5000A)
  resolution = Ref{PS5000ADeviceResolution}()
  ret = @ccall libps5000a.ps5000aGetDeviceResolution(
    scope.handle::Int16,
    resolution::Ref{PS5000ADeviceResolution}
  )::Int32
  if ret != 0
    error("Error while reading resolution: $ret")
  end

  return resolution.x

end

function set_device_resolution(scope::PS5000A, resolution::PS5000ADeviceResolution)
  ret = @ccall libps5000a.ps5000aSetDeviceResolution(
    scope.handle::Int16,
    Cint(resolution)::Cint
  )::Int32
  if ret != 0
    error("Error while setting resolution: $ret")
  end

  return ret

end


function set_channel(
  scope::PS5000A, 
  channel::PS5000AChannel, 
  enabled::Int16, 
  coupling::PS5000ACoupling, 
  range::PS5000ARange, 
  offset::Float32=0.0f0)
  @ccall libps5000a.ps5000aSetChannel(
    scope.handle::Int16,
    Cint(channel)::Cint,
    enabled::Int16,
    Cint(coupling)::Cint,
    Cint(range)::Cint,
    offset::Float32
  )::Int32
end
