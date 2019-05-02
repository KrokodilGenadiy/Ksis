unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, IdUDPClient, IdBaseComponent,
  IdComponent, IdUDPBase, IdUDPServer, Vcl.StdCtrls, IdGlobal, IdSocketHandle, WinSock, StrUtils,
  IdTCPConnection, IdTCPClient, IdCustomTCPServer, IdTCPServer, IdContext;

type
  TForm1 = class(TForm)
    Label1: TLabel;
    Edit1: TEdit;
    Edit2: TEdit;
    Label2: TLabel;
    Memo1: TMemo;
    IdUDPServer1: TIdUDPServer;
    IdUDPClient1: TIdUDPClient;
    Button1: TButton;
    IdTCPServer1: TIdTCPServer;
    IdTCPClient1: TIdTCPClient;
    Button2: TButton;
    Label3: TLabel;
    Memo2: TMemo;
    CheckBox1: TCheckBox;
    Button3: TButton;
    Label4: TLabel;
    Edit3: TEdit;
    procedure Button1Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure IdUDPServer1UDPRead(AThread: TIdUDPListenerThread;
      const AData: TIdBytes; ABinding: TIdSocketHandle);
    procedure Button3Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure IdTCPServer1Execute(AContext: TIdContext);
    procedure Edit1KeyPress(Sender: TObject; var Key: Char);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
  private
    { Private declarations }
  public
      Spisok: array[1..10,1..2] of string;
      GlobalFlag : boolean;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}
function GetLocalIP: String;
const WSVer = $101;
var
  wsaData: TWSAData;
  P: PHostEnt;
  Buf: array [0..127] of Char;
begin
  Result := '';
  if WSAStartup(WSVer, wsaData) = 0 then begin
    if GetHostName(@Buf, 128) = 0 then begin
      P := GetHostByName(@Buf);
      if P <> nil then Result := iNet_ntoa(PInAddr(p^.h_addr_list^)^);
    end;
    WSACleanup;
  end;
end;

procedure TForm1.Button1Click(Sender: TObject);
var
mes,ip:string;
i: integer;
begin
if Edit1.Text = '' then
begin
  ShowMessage('Вы не ввели имя.');
  Exit;
end;
if GlobalFlag = True then
begin
  ShowMessage('Вы уже подключены.');
  Exit;
end;
  Edit3.Text := GetLocalIp;
  Edit1.Enabled := False;
  CheckBox1.Checked := True;
  GlobalFlag := True;
  ip := GetLocalIP;
  mes:=Edit1.Text+'/'+ip+':';
  IdUDPClient1.Send(mes);
  idTcpServer1.Active:=true;
  idTcpClient1.Port:=8000;
end;



procedure TForm1.Button2Click(Sender: TObject);
var i: integer;
ip ,Name: string;
begin
if GlobalFlag = False then
begin
  ShowMessage('Вы не подключены к чату.');
  Exit;
end;


for i:= 1 to 10 do
  if Spisok[i,2] <> '' then
  begin
    ip := Spisok[i,2];
    Name := Spisok[i,1];
    idTcpClient1.Host:=ip;
    idTcpClient1.Connect();
    if idTcpClient1.Connected = True then
      idTcpClient1.Socket.WriteLn('['+Name+'] :'+Edit2.Text)
    else
      begin
        ShowMessage('Не удаётся отправить сообщение.');
      end;
    idTcpClient1.Disconnect();
  end;
  Edit2.Text := '';
end;

procedure TForm1.Button3Click(Sender: TObject);
var mes,ip:String;
j,i:integer;
begin
if GlobalFlag = False then
begin
  ShowMessage('Вы уже отключены.');
  Exit;
end;
  for i:= 1 to 10 do
    if Spisok[i,2] <> '' then
    begin
      ip := Spisok[i,2];
      Name := Spisok[i,1];
      idTcpClient1.Host:=ip;
      idTcpClient1.Connect();
      idTcpClient1.Socket.WriteLn('['+Name+'] :'+'has left the chat.');
      idTcpClient1.Disconnect();
    end;

  Edit1.Enabled := True;
  ip := GetLocalIP;
  mes:='|'+Edit1.Text+'/'+ip+':'+'KONEC';
  IdUDPClient1.Send(mes);
  GlobalFlag := False;
  CheckBox1.Checked := False;
  for j := 1 to 10 do
      if Spisok[j,2] = ip then
      begin
      for i := 0 to memo1.lines.count do
        if pos(Spisok[j,1]+' '+Spisok[j,2],memo2.lines[i])>0 then
          Memo2.Lines.Delete(i);
        Spisok[j,1] := '';
        Spisok[j,2] := '';
      end;
  idTcpClient1.Disconnect();
end;



procedure TForm1.Edit1KeyPress(Sender: TObject; var Key: Char);
begin
 if not (Key in ['a'..'z', 'A'..'Z']) then   Key :=#0;
end;


procedure TForm1.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var i ,j: integer;
ip,mes : string;
begin
 for i:= 1 to 10 do
    if Spisok[i,2] <> '' then
    begin
      ip := Spisok[i,2];
      Name := Spisok[i,1];
      idTcpClient1.Host:=ip;
      idTcpClient1.Connect();
      idTcpClient1.Socket.WriteLn('['+Name+'] :'+'has left the chat.');
      idTcpClient1.Disconnect();
    end;

  Edit1.Enabled := True;
  ip := GetLocalIP;
  mes:='|'+Edit1.Text+'/'+ip+':'+'KONEC';
  IdUDPClient1.Send(mes);
  GlobalFlag := False;
  CheckBox1.Checked := False;
  for j := 1 to 10 do
      if Spisok[j,2] = ip then
      begin
      for i := 0 to memo1.lines.count do
        if pos(Spisok[j,1]+' '+Spisok[j,2],memo2.lines[i])>0 then
          Memo2.Lines.Delete(i);
        Spisok[j,1] := '';
        Spisok[j,2] := '';
      end;
  idTcpClient1.Disconnect();
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  Memo1.Lines.Clear;
  Memo2.Lines.Clear;
  GlobalFlag := False;
  CheckBox1.Checked := False;
  idTcpServer1.DefaultPort:=8000;
end;

procedure TForm1.IdTCPServer1Execute(AContext: TIdContext);
var
s,ip:string;
j,i,pos1,pos2: integer;
begin
if GlobalFlag = False then
  Exit;
s:= AContext.Connection.Socket.ReadLn;

if pos('+',s)<>0 then
  begin
    pos1 := pos('+',s);
    for i := pos1+1 to length(s) do
      ip := ip+s[i];
    idTcpClient1.Host:=ip;
    idTcpClient1.Connect();
    for i := 0 to Memo1.Lines.Count-1 do
      idTcpClient1.Socket.WriteLn(Memo1.Lines[i]);
    idTcpClient1.Disconnect();
  end
else
  Memo1.Lines.add('['+Timetostr(time)+'] '+ s);
end;


procedure TForm1.IdUDPServer1UDPRead(AThread: TIdUDPListenerThread;
  const AData: TIdBytes; ABinding: TIdSocketHandle);
 var
  ss:TStringStream;
  s,buff,ip,mes,StrokaIp:String;
  i,j,pos1,pos2: Integer;
  Flag: Boolean;
begin
ss:=TStringStream.create('');
ss.write(adata[0],length(adata));
s:=ss.DataString;

  if GlobalFlag = False then
    Exit;

  StrokaIp :='';
  Flag := True;

  if pos('|',s) <> 0 then
    Name:= copy(s,2,pos('/',s)-2)
  else
    Name:= copy(s,1,pos('/',s)-1);


    pos1 := pos('/',s);
    pos2 := pos(':',s);
    for i := pos1+1 to pos2-1 do
      StrokaIp := StrokaIp+s[i];

    if pos('|',s) <> 0 then
      for j := 1 to 10 do
      if Spisok[j,2] = StrokaIp then
      begin
      for i := 0 to memo1.lines.count do
        if pos(Spisok[j,1]+' '+Spisok[j,2],memo2.lines[i])<>0 then
          Memo2.Lines.Delete(i);
      Spisok[j,1] := '';
      Spisok[j,2] := '';
      idTcpClient1.Disconnect();
      Exit;
      end;

    i := 1;
  while i<=10 do
    begin
      for j := 1 to 10 do
      if Spisok[j,2] = StrokaIp then
      begin
        Flag := False;
        Break;
      end;

      if Flag = False then
      break;

      if (Spisok[i,1] = '') and (Flag = True) then
        begin
          Spisok[i,1] := Name;
          Spisok[i,2] := StrokaIp;
          Memo1.Lines.Add('['+Timetostr(time)+'] '+'['+Spisok[i,1]+'] :'+'Online.');
          ip := GetLocalIP;
          mes:=Edit1.Text+'/'+ip+':';
          IdUDPClient1.Send(mes);
          Memo2.Lines.Add(Spisok[i,1]+' '+Spisok[i,2]);
        end
    else
      i := i + 1;
    end;

end;


end.
