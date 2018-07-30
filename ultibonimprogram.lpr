program UltiboNimProgram;
{$mode delphi}

uses 
{$ifdef BUILD_RPI } BCM2708,BCM2835, {$endif}
{$ifdef BUILD_RPI2} BCM2709,BCM2836, {$endif}
{$ifdef BUILD_RPI3} BCM2710,BCM2837, {$endif}
GlobalConfig,GlobalConst,GlobalTypes,Platform,Threads,SysUtils,Classes,Console,Logging,Ultibo,FileSystem,MMC,FATFS;

type 
 PRingBufferOfInt = ^TRingBufferOfInt;
 TRingBufferOfInt = record
  BufferAddress:PInteger;
  Limit:Integer;
  ReadCounter:Integer;
  WriteCounter:Integer;
 end;

procedure RingBufferOfIntInit(var Buffer:TRingBufferOfInt);
begin
 with Buffer do
  begin
   Limit:=16*1024;
   BufferAddress:=PInteger(GetMem(4*Buffer.Limit));
   ReadCounter:=0;
   WriteCounter:=0;
  end;
end;

function RingBufferOfIntGet(var Buffer:TRingBufferOfInt; var X:Integer):Bool;
begin
 Result:=False;
 with Buffer do
  begin
   if ReadCounter <> WriteCounter then
    begin
     X:=BufferAddress[ReadCounter and (Limit - 1)];
     Inc(ReadCounter);
     Result:=True;
    end;
  end;
end;

procedure RingBufferOfIntPut(var Buffer:TRingBufferOfInt; X:Integer);
begin
 with Buffer do
  begin
   BufferAddress[WriteCounter and (Limit - 1)]:=X;
   Inc(WriteCounter);
  end;
end;

var 
 ClockBuffer,LedBuffer:TRingBufferOfInt;
 BlinkLoopHandle:TThreadHandle = INVALID_HANDLE_VALUE;
 CurrentMilliseconds,PrevMilliseconds:Integer;
 LedRequest:Integer;

procedure NimBlinkLoop(ClockBuffer,LedBuffer:PRingBufferOfInt); cdecl; external 'libultibonimlib' name 'nimBlinkLoop';
function BlinkLoop(Parameter:Pointer):PtrInt;
begin
 Result:=0;
 NimBlinkLoop(@ClockBuffer,@LedBuffer);
end;

procedure StartLogging;
begin
 LOGGING_INCLUDE_COUNTER:=False;
 LOGGING_INCLUDE_TICKCOUNT:=True;
 CONSOLE_REGISTER_LOGGING:=True;
 LoggingConsoleDeviceAdd(ConsoleDeviceGetDefault);
 LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_CONSOLE));
end;

begin
 while not DirectoryExists('C:\') do
  sleep(100);
 if FileExists('default-config.txt') then
  CopyFile('default-config.txt','config.txt',False);

 StartLogging;

 RingBufferOfIntInit(ClockBuffer);
 RingBufferOfIntInit(LedBuffer);
 BeginThread(@BlinkLoop,Nil,BlinkLoopHandle,THREAD_STACK_DEFAULT_SIZE);

 PrevMilliseconds:=0;
 ActivityLedEnable;
 while True do
  begin
   ThreadYield;
   CurrentMilliseconds:=GetTickCount;
   if PrevMilliseconds <> CurrentMilliseconds then
    begin
     RingBufferOfIntPut(ClockBuffer,CurrentMilliseconds);
     PrevMilliseconds:=CurrentMilliseconds;
    end;
   if RingBufferOfIntGet(LedBuffer,LedRequest) then
    begin
     if LedRequest = 0 then
      ActivityLedOn
     else
      ActivityLedOff;
    end;
  end;
end.
