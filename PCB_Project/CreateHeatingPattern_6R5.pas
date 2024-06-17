{..............................................................................}
{ Create heating pattern on rectangular area                                   }
{ Morian Sonnet                                                                }
{..............................................................................}

{
                            Width
    <----------------------------------------------->
    _________________________________________________
   (________________________   ______________________)    ^
    ________________________) (______________________     |
   (________________________   ______________________)    | Height
                            | |
                            ° °


width, height always refers to the middle of the track
}

{..............................................................................}

Const
     Orientation = 180; // 0 -> horizontal, other values are *90° -> rotation  // width and height rotate as well
Const
     StartCoordX = 90;
Const
     StartCoordY = 40;
Const
     Width = 60; // in mm
Const
     Height = 77; // in mm
Const
     LineWidth = 0.2; // in mm
Const
     IdealLineSep = 1.8; // long lines middle to middle distance in mm // ActualLineSep will be computed based on Height
Const
     LineCurveRadius = -1; // in mm, negative -> ActualLineSep/2
Const
     ConnectorCurveRadius = -1; // negative -> LineCurveRadius
Const ConnectorLineSep = 5; // negative -> ActualLineSep

//Var Group;


Function GetNumSeps(Height: real, IdealLineSep: real): integer;
Begin
     Result := 2*Round(((Height/IdealLineSep)-1)/2)+1;
End;

Function CheckValues(Dummy:integer = -1): integer;
Begin
     // not much checked yet
     Result := 0;
End;

Procedure RotateTrackAroundOrigin(track);
Var
   X1new, X2new, Y1new, Y2new, angle;
Begin
    angle := DegToRad(Orientation * 90);
    X1new := Cos(angle)*track.X1  - Sin(angle)*track.Y1;
    Y1new := Sin(angle)*track.X1  + Cos(angle)*track.Y1;

    X2new := Cos(angle)*track.X2  - Sin(angle)*track.Y2;
    Y2new := Sin(angle)*track.X2  + Cos(angle)*track.Y2;

    track.X1 := X1new; track.Y1 := Y1new; track.X2 := X2new; track.Y2 := Y2new;
End;

Procedure RotateArcAroundOrigin(arc);
Begin
    arc.RotateAroundXY(0,0,Orientation*90);
End;

Procedure MoveTrackArc(thing);
Begin
     thing.MoveByXY(MMsToCoord(StartCoordX),MMsToCoord(StartCoordY));
End;

Procedure CreateTrack(X1, X2, Y1, Y2, Layer, Board);
Var
   Track : ICPCB_Track;
Begin
               Track := PCBServer.PCBObjectFactory(eTrackObject, eNoDimension, eCreate_Default);
               Track.X1 := MMsToCoord(X1);
               Track.X2 := MMsToCoord(X2);
               Track.Y1 := MMsToCoord(Y1);
               Track.Y2 := MMsToCoord(Y2);
               Track.Layer := Layer;
               Track.Width := MMsToCoord(LineWidth);
               RotateTrackAroundOrigin(Track);
               MoveTrackArc(Track);
               Board.AddPCBObject(Track);
               PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Track.I_ObjectAddress);
End;

Procedure CreateArc(XC, YC, R, SA, EA, Layer, Board);
Var
   Arc : IPCB_Arc;
Begin
               Arc := PCBServer.PCBObjectFactory(eArcObject, eNoDimension, eCreate_Default);
               Arc.XCenter := MMsToCoord(XC);
               Arc.YCenter := MMsToCoord(YC);
               Arc.Radius := MMsToCoord(R);
               Arc.StartAngle := SA;
               Arc.EndAngle := EA;
               Arc.Layer := Layer;
               Arc.LineWidth := MMsToCoord(LineWidth);
               RotateArcAroundOrigin(Arc);
               MoveTrackArc(Arc);
               Board.AddPCBObject(Arc);
               PCBServer.SendMessageToRobots(Board.I_ObjectAddress, c_Broadcast, PCBM_BoardRegisteration, Arc.I_ObjectAddress);
End;





Procedure HeatingPatternCreation;
Var
   Board      : IPCB_Board;
   Track      : IPCB_Track;
   Arc        : IPCB_Arc;

   NumSeps : Integer;
   ActualLineCurveRadius : real;
   ActualConnectorCurveRadius : real;
   ActualConnectorLineSep : real;
   ActualLineSep : real;
   Layer : Integer;
   counter, side_counter : Integer;
Begin
     If CheckValues > 0 Then
        ShowMessage('Problem with given values, check again!');
     Board := PcbServer.GetCurrentPCBBoard();
     Layer := Board.CurrentLayer();   // eTopLayer (maybe use for footprint)

     NumSeps := GetNumSeps(Height, IdealLineSep);
     ActualLineSep := Height/NumSeps;
     ShowMessage('Actual Line Sep is ' + FloatToStr(ActualLineSep));

     If (LineCurveRadius < 0) or (LineCurveRadius > Height/NumSeps/2) Then
        ActualLineCurveRadius := Height/NumSeps/2
     Else
        ActualLineCurveRadius := LineCurveRadius;

     If ConnectorCurveRadius < 0 Then
        ActualConnectorCurveRadius := ActualLineCurveRadius
     Else
        ActualConnectorCurveRadius := ConnectorCurveRadius;

     If ConnectorLineSep < 0 Then
        ActualConnectorLineSep := Height/NumSeps
     Else
         ActualConnectorLineSep := ConnectorLineSep;

     PCBServer.PreProcess;

     // bottom horizontal lines
     For side_counter := 0 to 1 Do
     Begin
          CreateTrack((ActualConnectorLineSep/2+ActualConnectorCurveRadius)*(side_counter*2-1),(Width/2-ActualLineCurveRadius)*(side_counter*2-1),0.0,0.0,Layer, Board);
     End;
     // top hor line
     CreateTrack(-Width/2+ActualLineCurveRadius,Width/2-ActualLineCurveRadius,Height,Height,Layer, Board);
     // other hor lines
     For counter := 1 To NumSeps - 1 Do
     Begin
          For side_counter := 0 to 1 Do
          Begin
               CreateTrack((ActualLineSep/2+ActualLineCurveRadius)*(side_counter*2-1),(Width/2-ActualLineCurveRadius)*(side_counter*2-1),counter*ActualLineSep,counter*ActualLineSep,Layer, Board);
          End;
     End;

     // vertical lines
     If ActualLineSep > 2*ActualLineCurveRadius + 0.000001 Then
        For counter := 0 To NumSeps - 1 Do
        Begin
            For side_counter := 0 to 1 Do
            Begin
                CreateTrack((Width/2*((counter + 1) mod 2)+ActualLineSep/2*(counter mod 2))*(2*side_counter - 1),(Width/2*((counter + 1) mod 2)+ActualLineSep/2*(counter mod 2))*(2*side_counter - 1),counter*ActualLineSep+ActualLineCurveRadius,(counter+1)*ActualLineSep-ActualLineCurveRadius,Layer, Board);
            End;
        End;

     // connector curves
     For side_counter := 0 to 1 Do
     Begin
          CreateArc((ActualConnectorLineSep/2+ActualConnectorCurveRadius)*(side_counter*2-1),-ActualConnectorCurveRadius,ActualConnectorCurveRadius,90*side_counter,90+90*side_counter, Layer, Board);
     End;

     // outer curves
     For counter := 0 To NumSeps Do
     Begin
         For side_counter := 0 to 1 Do
         Begin
               CreateArc((Width/2-ActualLineCurveRadius)*(side_counter*2-1),counter*ActualLineSep+(1-(counter mod 2)*2)*ActualLineCurveRadius,ActualLineCurveRadius,90*(1-side_counter)*(counter mod 2)+(180+90*side_counter)*((counter+1) mod 2),90+90*(1-side_counter)*(counter mod 2)+(180+90*side_counter)*((counter+1) mod 2), Layer, Board);
         End;
     End;

     // inner curves
     For counter := 1 To NumSeps - 1 Do
     Begin
         For side_counter := 0 To 1 Do
         Begin
              CreateArc((ActualLineSep/2+ActualLineCurveRadius)*(side_counter*2-1),counter*ActualLineSep+((counter mod 2)*2-1)*ActualLineCurveRadius,ActualLineCurveRadius,90*(side_counter)*((counter+1) mod 2)+(180+90*(1-side_counter))*(counter mod 2),90+90*(side_counter)*((counter+1) mod 2)+(180+90*(1-side_counter))*(counter mod 2), Layer, Board);
         End;
     End;


     PCBServer.PostProcess;

End;


{..............................................................................}

{..............................................................................}
