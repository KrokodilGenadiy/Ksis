unit uMain;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, WinSock, Spin;

{$DEFINE NO_MESSAGE}

const
  ICMP = 'ICMP.DLL';
  RES_UNKNOWN   = 'Unknown';
  WSA_TYPE = $101;
  STR_TRACE = 'Трассировка маршрута к ';
  STR_JUMP = 'с максимальным числом прыжков ';
  STR_DONE = 'Трассировка завершена.' + #13#10;
  HOST_NOT_REPLY = 'Превышен интервал ожидания для запроса.';
  
type
  IP_INFO = packed record
    Ttl: Byte;
    Tos: Byte;
    IPFlags: Byte;
    OptSize: Byte;
    Options: Pointer;
  end;
  PIP_INFO = ^IP_INFO;

  ICMP_ECHO = packed record
    Source: Longint;
    Status: Longint;
    RTTime: Longint;
    DataSize: Word;
    Reserved: Word;
    pData: Pointer;
    i_ipinfo: IP_INFO;
  end;

  TfrmMain = class(TForm)
    edAddr: TEdit;
    btnStart: TButton;
    sedCount: TSpinEdit;
    memShowTracert: TMemo;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    procedure btnStartClick(Sender: TObject);
  end;

  TTraceThread = class(TThread)
  private
    DestAddr: in_addr;
    TraceHandle: THandle;
    DestinationAddress,
    ReportString: String;
    IterationCount: Byte;
  public
    procedure Execute; override;
    procedure Log;
    function Trace(const Iteration: Byte): Longint;
  end;

var
  frmMain: TfrmMain;

implementation

{$R *.dfm}

  function IcmpCreateFile: THandle; stdcall; external ICMP name 'IcmpCreateFile';
  function IcmpCloseHandle(IcmpHandle: THandle): BOOL; stdcall;
    external ICMP name 'IcmpCloseHandle';
  function IcmpSendEcho(IcmpHandle : THandle; DestAddress: Longint;
    RequestData: Pointer; RequestSize: Word; RequestOptns: PIP_INFO;
    ReplyBuffer: Pointer; ReplySize, Timeout: DWORD): DWORD; stdcall;
    external ICMP name 'IcmpSendEcho';

{ Other functions }

// Функция возвращает имя хоста по его IP адресу
function GetNameFromIP(const IP: String): String;
const
  ERR_INADDR    = 'Can not convert IP to in_addr.';
  ERR_HOST      = 'Can not get host information.';
  ERR_WSA       = 'Can not initialize WSA.';
var
  WSA   : TWSAData;
  Host  : PHostEnt;
  Addr  : u_long;
  Err   : Integer;
begin
  Result := RES_UNKNOWN;
  Err := WSAStartup(WSA_TYPE, WSA);
  if Err <> 0 then
  begin
    {$IFNDEF NO_MESSAGE}
      MessageDlg(ERR_WSA, mtError, [mbOK], 0);
    {$ENDIF}
    Exit;
  end;
  try
    Addr := inet_addr(PChar(IP));
    if Addr = u_long(INADDR_NONE) then
    begin
      {$IFNDEF NO_MESSAGE}
        MessageDlg(ERR_INADDR, mtError, [mbOK], 0);
      {$ENDIF}
      Exit;
    end;
    Host := gethostbyaddr(@Addr, SizeOf(Addr), PF_INET);
    if Assigned(Host) then
      Result := Host.h_name
    {$IFNDEF NO_MESSAGE}
      else
        MessageDlg(ERR_HOST, mtError, [mbOK], 0)
    {$ENDIF}
    ;
  finally
    WSACleanup;
  end;
end;

// Функция преобразует IP адрес в его строковый эквивалент
function GetDottetIP(const IP: Longint): String;
begin
  Result := Format('%d.%d.%d.%d', [IP and $FF,
    (IP shr 8) and $FF, (IP shr 16) and $FF, (IP shr 24) and $FF]);
end;

{ TfrmMain }

procedure TfrmMain.btnStartClick(Sender: TObject);
begin
  with TTraceThread.Create(False) do
  begin
    FreeOnTerminate := True;
    DestinationAddress := edAddr.Text;
    IterationCount := sedCount.Value;
    Resume;
  end;
end;

procedure TTraceThread.Execute;
var
  WSAData: TWSAData;
  Host: PHostEnt;
  Error,
  TickStart: DWORD;
  Result: Longint;
  I,
  Iteration: Byte;
  HostName: String;
  HostReply: Boolean;
  HostIP: LongInt;
begin
  Error := WSAStartup(WSA_TYPE, WSAData);
  if Error <> 0 then
  begin
    ReportString := SysErrorMessage(WSAGetLastError);
    Synchronize(Log);
    Exit;
  end;

  try
    Host := gethostbyname(PChar(DestinationAddress));
    if not Assigned(Host) then
    begin
      ReportString := SysErrorMessage(WSAGetLastError);
      Synchronize(Log);
      Exit;
    end;

    DestAddr := PInAddr(Host.h_addr_list^)^;

    TraceHandle := IcmpCreateFile;
    if TraceHandle = INVALID_HANDLE_VALUE then
    begin
      ReportString := SysErrorMessage(GetLastError);
      Synchronize(Log);
      Exit;
    end;

    try
      ReportString := STR_TRACE + DestinationAddress
        + ' [' + GetDottetIP(DestAddr.S_addr)+ ']' + #13#10;
      Synchronize(Log);
      ReportString := STR_JUMP + IntToStr(IterationCount) + ':' + #13#10;
      Synchronize(Log);


      Result := 0;
      Iteration := 0;


      while (Result <> DestAddr.S_addr) and
            (Iteration < IterationCount) do
      begin
        Inc(Iteration);

        HostReply := False;


        for I := 0 to 2 do
        begin
          TickStart := GetTickCount;
          Result := Trace(Iteration);

          if Result = -1 then
            ReportString := '    *    '
          else
          begin
            ReportString := Format('%6d ms', [GetTickCount - TickStart]);
            HostReply := True;
            HostIP := Result;
          end;


          if I = 0 then
            ReportString := Format('%3d: %s', [Iteration, ReportString]);
            
          Synchronize(Log);
        end;

        if HostReply then
        begin
          ReportString := GetDottetIP(HostIP);
          HostName := GetNameFromIP(ReportString);
          if HostName <> RES_UNKNOWN then
            ReportString := HostName + '[' + ReportString + ']';
          ReportString := ReportString + #13#10;
        end
        else
          ReportString := HOST_NOT_REPLY + #13#10;


        ReportString := '  ' + ReportString;
        Synchronize(Log);
      end;

    finally
      IcmpCloseHandle(TraceHandle);
    end;


    ReportString := STR_DONE;
    Synchronize(Log);
  finally
    WSACleanup;
  end;
end;

// Процедура отвечает за вывод информации в memShowTracert
procedure TTraceThread.Log;
begin
  frmMain.memShowTracert.Text :=
    frmMain.memShowTracert.Text + ReportString;
  SendMessage(frmMain.memShowTracert.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

// Однократная посылка эхозапроса
function TTraceThread.Trace(const Iteration: Byte): Longint;
var
  IP: IP_INFO;
  ECHO: ^ICMP_ECHO;
  Error: Integer;
begin
  GetMem(ECHO, SizeOf(ICMP_ECHO));
  try
    with IP do
    begin
      Ttl := Iteration;
      IPFlags := 0;
      OptSize := 0;
      Options := nil;
    end;

    Error := IcmpSendEcho(TraceHandle,
                          DestAddr.S_addr,
                          nil,
                          0,
                          @IP,
                          ECHO,
                          SizeOf(ICMP_ECHO),
                          5000);
    if Error = 0 then
    begin
      Result := -1;
      Exit;
    end;



  finally
    FreeMem(ECHO);
  end;

end;

end.

