VERSION 5.00
Begin VB.Form FormFillContentAware 
   Appearance      =   0  'Flat
   BackColor       =   &H80000005&
   BorderStyle     =   4  'Fixed ToolWindow
   Caption         =   "Content-aware fill"
   ClientHeight    =   6300
   ClientLeft      =   45
   ClientTop       =   390
   ClientWidth     =   12060
   DrawStyle       =   5  'Transparent
   BeginProperty Font 
      Name            =   "Tahoma"
      Size            =   8.25
      Charset         =   0
      Weight          =   400
      Underline       =   0   'False
      Italic          =   0   'False
      Strikethrough   =   0   'False
   EndProperty
   HasDC           =   0   'False
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   420
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   804
   ShowInTaskbar   =   0   'False
   Begin PhotoDemon.pdButtonStrip btsFillOrder 
      Height          =   975
      Left            =   240
      TabIndex        =   6
      Top             =   120
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "fill order"
   End
   Begin PhotoDemon.pdSlider sldOptions 
      Height          =   975
      Index           =   1
      Left            =   6240
      TabIndex        =   1
      Top             =   120
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "patch test size"
      min             =   4
      max             =   50
      value           =   20
      notchposition   =   2
      notchvaluecustom=   20
   End
   Begin PhotoDemon.pdCommandBar cmdBar 
      Align           =   2  'Align Bottom
      Height          =   750
      Left            =   0
      TabIndex        =   0
      Top             =   5550
      Width           =   12060
      _extentx        =   21273
      _extenty        =   1323
   End
   Begin PhotoDemon.pdSlider sldOptions 
      Height          =   975
      Index           =   2
      Left            =   6240
      TabIndex        =   2
      Top             =   1200
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "random patch candidates"
      min             =   5
      max             =   200
      value           =   60
      notchposition   =   2
      notchvaluecustom=   60
   End
   Begin PhotoDemon.pdSlider sldOptions 
      Height          =   975
      Index           =   3
      Left            =   240
      TabIndex        =   3
      Top             =   2280
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "refinement (percent)"
      max             =   99
      value           =   50
      notchposition   =   2
      notchvaluecustom=   50
   End
   Begin PhotoDemon.pdSlider sldOptions 
      Height          =   975
      Index           =   4
      Left            =   6240
      TabIndex        =   4
      Top             =   2280
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "patch perfection threshold"
      min             =   1
      max             =   100
      value           =   15
      notchposition   =   2
      notchvaluecustom=   15
   End
   Begin PhotoDemon.pdSlider sldOptions 
      Height          =   975
      Index           =   0
      Left            =   240
      TabIndex        =   5
      Top             =   1200
      Width           =   5655
      _extentx        =   9975
      _extenty        =   1720
      caption         =   "search radius"
      min             =   5
      max             =   500
      value           =   200
      notchposition   =   2
      notchvaluecustom=   200
   End
End
Attribute VB_Name = "FormFillContentAware"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
'***************************************************************************
'Content-Aware Fill (aka "Heal Selection" in some software) Settings Dialog
'Copyright 2022-2022 by Tanner Helland
'Created: 03/May/22
'Last updated: 03/May/22
'Last update: initial build
'
'Content-aware fill was added in PhotoDemon 9.0.  This simple dialog serves a simple purpose:
' allowing the user to modify various content-aware settings.  When OK is pressed, those settings
' are forwarded to an instance of the pdInpaint class, which performs the actual content-aware fill.
' Please review that class for further details on the algorithm and how it works.
'
'Unless otherwise noted, all source code in this file is shared under a simplified BSD license.
' Full license details are available in the LICENSE.md file, or at https://photodemon.org/license/
'
'***************************************************************************

Option Explicit

'These constants are copied directly from pdInpaint
Private Const MAX_NEIGHBORS_DEFAULT As Long = 20
Private Const COMPARE_RADIUS_DEFAULT As Long = 200
Private Const RANDOM_CANDIDATES_DEFAULT As Long = 60
Private Const REFINEMENT_DEFAULT As Double = 0.5
Private Const ALLOW_OUTLIERS_DEFAULT As Double = 0.15

Private Sub cmdBar_OKClick()
    
    'Place all settings in an XML string
    Dim cParams As pdSerialize
    Set cParams = New pdSerialize
    With cParams
        .AddParam "search-radius", sldOptions(0).Value
        .AddParam "patch-size", sldOptions(1).Value
        .AddParam "random-candidates", sldOptions(2).Value
        .AddParam "refinement", sldOptions(3).Value / 100#
        .AddParam "allow-outliers", sldOptions(4).Value / 100#
        .AddParam "fill-order", btsFillOrder.ListIndex
    End With
    
    Processor.Process "Content-aware fill", False, cParams.GetParamString(), UNDO_Layer
    
End Sub

Private Sub cmdBar_ResetClick()
    btsFillOrder.ListIndex = 0
    sldOptions(0).Value = COMPARE_RADIUS_DEFAULT
    sldOptions(1).Value = MAX_NEIGHBORS_DEFAULT
    sldOptions(2).Value = RANDOM_CANDIDATES_DEFAULT
    sldOptions(3).Value = REFINEMENT_DEFAULT * 100#
    sldOptions(4).Value = ALLOW_OUTLIERS_DEFAULT * 100#
End Sub

Private Sub Form_Load()
    
    cmdBar.SetPreviewStatus False
    
    btsFillOrder.AddItem "random", 0
    btsFillOrder.AddItem "outside-in", 1
    btsFillOrder.AddItem "inside-out", 2
    
    'Apply translations and visual themes
    ApplyThemeAndTranslations Me
    
    cmdBar.SetPreviewStatus True
    
End Sub

Private Sub Form_Unload(Cancel As Integer)
    ReleaseFormTheming Me
End Sub
