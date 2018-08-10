program UltiboNimProgram;
{$mode delphi}

uses 
{$ifdef BUILD_QEMUVPB} QEMUVersatilePB, {$endif}
{$ifdef BUILD_RPI    } BCM2708,BCM2835, {$endif}
{$ifdef BUILD_RPI2   } BCM2709,BCM2836, {$endif}
{$ifdef BUILD_RPI3   } BCM2710,BCM2837, {$endif}
GlobalConfig,GlobalConst,GlobalTypes,Platform,Threads,SysUtils,Classes,Console,Logging,Ultibo,Services,
Mouse,
FileSystem,MMC,FATFS,
HTTP,WebStatus,
DWCOTG,SMSC95XX,LAN78XX,
VersatilePb;

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
 Console1,Console2,Console3:TWindowHandle;
 MouseData:TMouseData;
 MouseCount:LongWord;

procedure SerialMessage(S:String);
var 
 C:Char;
procedure SerialByte(C:Char);
begin
 PLongWord(VERSATILEPB_UART0_REGS_BASE)^ := Ord(C);
end;
begin
 for C in S do
  SerialByte(C);
 SerialByte(Char(13));
 SerialByte(Char(10));
end;

procedure Log(Message:String);
begin
 LoggingOutput(Message);
 SerialMessage(Message);
end;

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
 if (SysUtils.GetEnvironmentVariable('PUBLIC_HOST') <> '') and (SysUtils.GetEnvironmentVariable('PUBLIC_VNC_PORT') <> '') then
  begin
   AddContent(AResponse,'<hr>');
   AddContent(AResponse,Format('<a href="http://novnc.com/noVNC/vnc.html?host=%s&port=%s&reconnect_delay=5000">VNC to console (you will then need to click connect and then if on a tablet possibly touch the screen to force a refresh)</a>',[SysUtils.GetEnvironmentVariable('PUBLIC_HOST'),SysUtils.GetEnvironmentVariable('PUBLIC_VNC_PORT')]));
  end;
 AddContent(AResponse,'<hr>');
 AddContent(AResponse,Format('<div>%s %s</div>',[BoardTypeToString(BoardGetType),MachineTypeToString(MachineGetType)]));
 AddContent(AResponse,Format('<div>%s %s %s</div>',[CPUArchToString(CPUGetArch),CPUTypeToString(CPUGetType),CPUModelToString(CPUGetModel)]));
 AddContent(AResponse,Format('<div>%d cpus %d bytes ram</div>',[CPUGetCount,MemoryGetSize]));
 AddContent(AResponse,'<hr>');
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
 // while True do
 //  Sleep(1*1000);
end;

procedure StartLogging;
begin
 LOGGING_INCLUDE_COUNTER:=False;
 LOGGING_INCLUDE_TICKCOUNT:=True;
 CONSOLE_REGISTER_LOGGING:=True;
 CONSOLE_LOGGING_POSITION:=CONSOLE_POSITION_TOPRIGHT;
 LoggingConsoleDeviceAdd(ConsoleDeviceGetDefault);
 LoggingDeviceSetDefault(LoggingDeviceFindByType(LOGGING_TYPE_CONSOLE));
end;

begin
 if BoardGetType <> BOARD_TYPE_QEMUVPB then
  begin
   while not DirectoryExists('C:\') do
    sleep(100);
   if FileExists('default-config.txt') then
    CopyFile('default-config.txt','config.txt',False);
  end;

 StartLogging;
 Log('');
 Log('UltiboNimProgram started');

 Console1 := ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_TOPLEFT,True);
 Console2 := ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_BOTTOMLEFT,False);
 Console3 := ConsoleWindowCreate(ConsoleDeviceGetDefault,CONSOLE_POSITION_BOTTOMRIGHT,False);
 ConsoleWindowSetBackcolor(Console1,COLOR_BLACK);
 ConsoleWindowSetForecolor(Console1,COLOR_YELLOW);
 ConsoleWindowSetBackcolor(Console2,COLOR_CYAN);
 ConsoleWindowSetForecolor(Console3,COLOR_GREEN);
 ConsoleWindowClear(Console1);
 ConsoleWindowClear(Console2);
 ConsoleWindowClear(Console3);

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
   MouseReadEx(@MouseData,SizeOf(TMouseData),MOUSE_FLAG_NON_BLOCK,MouseCount);
   CurrentMilliseconds:=GetTickCount;
   if PrevMilliseconds <> CurrentMilliseconds then
    begin
     RingBufferOfIntPut(ClockBuffer,CurrentMilliseconds);
     PrevMilliseconds:=CurrentMilliseconds;
     if CurrentMilliseconds mod 1000 = 0 then
      begin
       ConsoleWindowSetXY(Console1,1,1);
       ConsoleWindowWriteLn(Console1,'When viewing on a tablet,');
       ConsoleWindowWriteLn(Console1,' you may need to touch the screen to refresh this image');
       ConsoleWindowWriteLn(Console1,'');
       ConsoleWindowWriteLn(Console1,Format('Up %s',[TimeToString(SystemFileTimeToDateTime(UpTime))]));
       ConsoleWindowWriteLn(Console1,Format('ClockBuffer.WriteCounter %d',[ClockBuffer.WriteCounter]));
       ConsoleWindowWriteLn(Console1,Format('LedBuffer.WriteCounter %d',[LedBuffer.WriteCounter]));
      end;
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
