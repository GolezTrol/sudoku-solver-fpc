program sudokusolver;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  Linux, unixtype
  { you can add units after this };

type
  TCell = class
    Value: Integer;
    Original: Boolean;
    Neighbors: Array[0..19] of TCell;
  end;

  { TSudoku }

  TSudoku = class
    Cells: array[0..80] of TCell;
    constructor Create;
    destructor Destroy; override;
    procedure Load(Sudoku: String);
    function IndexOf(X, Y: Integer): Integer;
    procedure XY(Index: Integer; out X, Y: Integer);
    function Solve: Boolean;
    function ToString: String;
  end;

  { TSudokuApp }

  TSudokuApp = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

function npp(var n: Integer): Integer;
begin
  Result := n;
  Inc(n);
end;

constructor TSudoku.Create;
var
  i, n, x, y, qx, qy, dx, dy: Integer;
begin
  for i := Low(Cells) to High(Cells) do
    Cells[i] := TCell.Create;

  for i := Low(Cells) to High(Cells) do
  begin
    n := 0;
    // Neighbors in column
    XY(i, x, y);
    for dy := 0 to 8 do
      if dy <> y then
        Cells[i].Neighbors[npp(n)] := Cells[IndexOf(x, dy)];
    // Neighbors in row
    XY(i, x, y);
    for dx := 0 to 8 do
      if dx <> x then
        Cells[i].Neighbors[npp(n)] := Cells[IndexOf(dx, y)];
    XY(i, x, y);
    // Remaining neighbors in the same square
    qx := (x div 3) * 3; // get top left of square
    qy := (y div 3) * 3;
    for dx := qx to qx + 2 do
      for dy := qy to qy + 2 do
        if (dx <> x) and (dy <> y) then // Only those not on the same row or column
          Cells[i].Neighbors[npp(n)] := Cells[IndexOf(dx, dy)];
  end;
end;

destructor TSudoku.Destroy;
var
  cell: TCell;
begin
  for cell in Cells do
    cell.Free;
  inherited Destroy;
end;

procedure TSudoku.Load(Sudoku: String);
var
  i, v: Integer;
begin
  for i := Low(Cells) to High(Cells) do
  begin
    v := Ord(Sudoku[i+1]) - Ord('0');
    Cells[i].Value := v;
    Cells[i].Original := v > 0;
  end;
end;

function TSudoku.IndexOf(X, Y: Integer): Integer;
begin
  Result := Y * 9 + X;
end;

procedure TSudoku.XY(Index: Integer; out X, Y: Integer);
begin
  Y := Index div 9;
  X := Index mod 9;
end;

function TSudoku.Solve: Boolean;
var
  i, v: Integer;
  Cell, Neighbor: TCell;
  ok: Boolean;
  Claims: Integer;
begin
  i := -1;
  repeat
    // Get the next cell that can be modified
    repeat
      if i = 80 then
        Exit(True); // Done. 81 cells filled in correctly
      Inc(i);
      cell := Cells[i];
    until not Cell.Original;

    // Find the next number the current cell can contain

    Claims := 0;
    for Neighbor in Cell.Neighbors do
      Claims := Claims or (1 shl Neighbor.Value);

    ok := False;
    for v := cell.Value + 1 to 9 do
    begin
      ok := (Claims and (1 shl v) = 0);

      if ok then
      begin
        Cell.Value := v; // The current v is available. Proceed.
        Break;
      end;
    end;

    if not ok then
    begin
      // No valid number found for the current cell. Backtrack
      Cell.Value := 0;
      repeat
        if i = 0 then
          Exit(False); // No more cells to backtrack, no solution found
        Dec(i);
        Cell := Cells[i];
      until not cell.Original;
      Dec(i);
    end;

  until False;


end;

function TSudoku.ToString: String;
var
  Cell: TCell;
begin
  Result := '';
  for Cell in Cells do
    Result := Result + Cell.Value.ToString;
end;

{ TSudokuApp }

procedure TSudokuApp.DoRun;
var
  ErrorMsg, sudoku: String;
  StartTime, EndTime: TTimeSpec;
  s, n, ms, totalms: Int64;
  sl: TStringList;
  i: Integer;
  PuzzleCount: Integer;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('h', 'help');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  totalms := 0;
  sl := TStringList.Create;
  try
    sl.LoadFromFile('5.txt');
    sl.Insert(0, '100007090030020008009600500005300900010080002600004000300000010040000007007000300');
    sl.Insert(1, '008034060100080000700010000003000000020500910900000007006003801300000020000900040');

    PuzzleCount := sl.Count;
    PuzzleCount := 1000;

    with TSudoku.Create do
    try
      for i := 0 to PuzzleCount - 1 do
      begin
        clock_gettime(CLOCK_MONOTONIC,@StartTime);
        sudoku := sl[i]; //'100007090030020008009600500005300900010080002600004000300000010040000007007000300';
        Load(sudoku);
        WriteLn(ToString);

        if not Solve then
          WriteLn('no solution');

        WriteLn(ToString);

        clock_gettime(CLOCK_MONOTONIC,@EndTime);
        if (EndTime.tv_nsec < StartTime.tv_nsec) then
        begin
          s := EndTime.tv_sec - StartTime.tv_sec - 1;
          n := 1000000000 + EndTime.tv_nsec - StartTime.tv_nsec;
        end else
        begin
          s := EndTime.tv_sec - StartTime.tv_sec;
          n := EndTime.tv_nsec - StartTime.tv_nsec;
        end;
        ms := ((s * 1000000000) + n) div 1000;
        totalms := totalms + ms;
        WriteLn('done in ', ms, ' μs');
      end;
    finally
      Free;
    end;
    WriteLn('Average ', Round(totalms / PuzzleCount), ' μs');

  finally
    sl.Free;
  end;

  // stop program loop
  Terminate;
end;

constructor TSudokuApp.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TSudokuApp.Destroy;
begin
  inherited Destroy;
end;

procedure TSudokuApp.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TSudokuApp;
begin
  Application:=TSudokuApp.Create(nil);
  Application.Title:='Sudoko gone mad';
  Application.Run;
  Application.Free;
end.

