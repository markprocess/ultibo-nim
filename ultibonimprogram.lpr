program UltiboNimProgram;
{$mode delphi}

uses 
{$ifdef BUILD_RPI } BCM2708,BCM2835, {$endif}
{$ifdef BUILD_RPI2} BCM2709,BCM2836, {$endif}
{$ifdef BUILD_RPI3} BCM2710,BCM2837, {$endif}
GlobalConfig,GlobalConst,GlobalTypes,Platform,Threads,SysUtils,Classes,Console,Logging,Ultibo,
FileSystem,MMC,FATFS,
DWCOTG,WebStatus,SMSC95XX,LAN78XX,HTTP;

type 
 PRingBufferOfInt = ^TRingBufferOfInt;
 TRingBufferOfInt = record
  BufferAddress:PInteger;
  Limit:Integer;
  ReadCounter:Integer;
  WriteCounter:Integer;
 end;

 TUltiboNimWebStatus = class(TWebStatusCustom)
  function DoContent(AHost:THTTPHost;ARequest:THTTPServerRequest;AResponse:THTTPServerResponse):Boolean;override;
 end;

var 
 ClockBuffer,LedBuffer:TRingBufferOfInt;
 BlinkLoopHandle:TThreadHandle = INVALID_HANDLE_VALUE;
 CurrentMilliseconds,PrevMilliseconds:Integer;
 LedRequest:Integer;
 HTTPListener:THTTPListener;
 HTTPRedirect:THTTPRedirect;
 UltiboNimWebStatus:TUltiboNimWebStatus;

function TimeToString(Time:TDateTime):String;
begin
 Result:=IntToStr(Trunc(Time)) + ' days ' + TimeToStr(Time);
end;

function TUltiboNimWebStatus.DoContent(AHost:THTTPHost;ARequest:THTTPServerRequest;AResponse:THTTPServerResponse):Boolean;
var 
 WorkTime:TDateTime;
begin
 AddContent(AResponse,'<div><big><big><b><div>Ultibo and Nim</div><div><a href=https://github.com/markprocess/ultibo-nim/blob/master/README.md>Source Repository</a></div></b>');
 WorkTime:=SystemFileTimeToDateTime(UpTime);
 AddContent(AResponse,Format('<div>Up %s</div>',[TimeToString(WorkTime)]));
 AddContent(AResponse,Format('<div>ClockBuffer.WriteCounter %d</div>',[ClockBuffer.WriteCounter]));
 AddContent(AResponse,Format('<div>LedBuffer.WriteCounter %d</div>',[LedBuffer.WriteCounter]));
 AddContent(AResponse,'</big></big></div>');
 Result:=True;
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

 HTTPListener:=THTTPListener.Create;
 HTTPListener.Active:=True;
 WEBSTATUS_FONT_NAME:='Monospace';
 WebStatusRegister(HTTPListener,'','',False);
 UltiboNimWebStatus:=TUltiboNimWebStatus.Create('Ultibo and Nim','/ultibonim',1);
 HTTPListener.RegisterDocument('',UltiboNimWebStatus);
 HTTPRedirect:=THTTPRedirect.Create;
 HTTPRedirect.Name:='/';
 HTTPRedirect.Location:='/status/ultibonim';
 HTTPListener.RegisterDocument('',HTTPRedirect);

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
