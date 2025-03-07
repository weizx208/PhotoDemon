Attribute VB_Name = "FileMenu"
'***************************************************************************
'File Menu Handler
'Copyright 2001-2023 by Tanner Helland
'Created: 15/Apr/01
'Last updated: 16/June/22
'Last update: remove an unused variable
'
'Functions for controlling standard file menu options.  Currently only handles "open image" and "save image".
'
'Unless otherwise noted, all source code in this file is shared under a simplified BSD license.
' Full license details are available in the LICENSE.md file, or at https://photodemon.org/license/
'
'***************************************************************************

Option Explicit

'This subroutine loads an image - note that the interesting stuff actually happens in PhotoDemon_OpenImageDialog, below
Public Sub MenuOpen()

    Dim listOfFiles As pdStringStack
    If PhotoDemon_OpenImageDialog(listOfFiles, GetModalOwner().hWnd) Then
        
        If (listOfFiles.GetNumOfStrings > 1) Then
            Loading.LoadMultipleImageFiles listOfFiles
        Else
            Loading.LoadFileAsNewImage listOfFiles.GetString(0)
        End If
        
    End If
    
End Sub

'Pass this function a string array, and it will fill it with a list of files selected by the user.
' The commondialog filters are automatically set according to image formats supported by the program.
Public Function PhotoDemon_OpenImageDialog(ByRef dstStringStack As pdStringStack, ByVal ownerHwnd As Long) As Boolean
    
    If (dstStringStack Is Nothing) Then Set dstStringStack = New pdStringStack
    
    'Disable user input until the dialog closes
    Interface.DisableUserInput
    
    'Get the last "open image" path from the preferences file
    Dim tempPathString As String
    tempPathString = UserPrefs.GetPref_String("Paths", "Open Image", vbNullString)
    
    'Prep a common dialog interface
    Dim openDialog As pdOpenSaveDialog
    Set openDialog = New pdOpenSaveDialog
    
    'Retrieve one (or more) files to open
    If openDialog.GetOpenFileNames_AsStringStack(dstStringStack, vbNullString, vbNullString, True, ImageFormats.GetCommonDialogInputFormats, g_LastOpenFilter, tempPathString, g_Language.TranslateMessage("Open an image"), vbNullString, ownerHwnd) Then
        
        'Message "Preparing to load image..."
        
        'Save the base folder and active file filter to the user's pref file
        UserPrefs.SetPref_String "Paths", "Open Image", Files.FileGetPath(dstStringStack.GetString(0))
        UserPrefs.SetPref_Long "Core", "Last Open Filter", g_LastOpenFilter
        
        PhotoDemon_OpenImageDialog = True
        
    'If the user cancels the commondialog box, simply exit out.
    Else
        PhotoDemon_OpenImageDialog = False
    End If
    
    'Re-enable user input
    Interface.EnableUserInput
        
End Function

'Provide a common dialog that allows the user to retrieve a single image filename, which the calling function can
' then use as it pleases.
Public Function PhotoDemon_OpenImageDialog_Simple(ByRef userImagePath As String, ByVal ownerHwnd As Long) As Boolean

    'Disable user input until the dialog closes
    Interface.DisableUserInput
    
    'Common dialog interface
    Dim openDialog As pdOpenSaveDialog
    Set openDialog = New pdOpenSaveDialog
    
    'Get the last "open image" path from the preferences file
    Dim tempPathString As String
    tempPathString = UserPrefs.GetPref_String("Paths", "Open Image", vbNullString)
        
    'Use Steve McMahon's excellent Common Dialog class to launch a dialog (this way, no OCX is required)
    If openDialog.GetOpenFileName(userImagePath, , True, False, ImageFormats.GetCommonDialogInputFormats, g_LastOpenFilter, tempPathString, g_Language.TranslateMessage("Select an image"), , ownerHwnd) Then
        
        'Save the new directory as the default path for future usage
        tempPathString = Files.FileGetPath(userImagePath)
        UserPrefs.SetPref_String "Paths", "Open Image", tempPathString
        
        'Also, remember the file filter for future use (in case the user tends to use the same filter repeatedly)
        UserPrefs.SetPref_Long "Core", "Last Open Filter", g_LastOpenFilter
        
        'All done!
        PhotoDemon_OpenImageDialog_Simple = True
        
    'If the user cancels the common dialog box, simply exit out
    Else
        
        PhotoDemon_OpenImageDialog_Simple = False
        
    End If
        
    'Re-enable user input
    Interface.EnableUserInput
    
End Function

'Subroutine for saving an image to file.  This function assumes the image already exists on disk and is simply
' being replaced; if the file does not exist on disk, this routine will automatically transfer control to Save As.
Public Function MenuSave(ByRef srcImage As pdImage) As Boolean
    
    'Certain criteria make is impossible to blindly save an image to disk (such as the image being loaded from a
    ' non-disk source, like the clipbord).  When this happens, we'll silently switch to a Save As... dialog.
    If Saving.IsCommonDialogRequired(srcImage) Then
        MenuSave = MenuSaveAs(srcImage)
    
    'This image has been saved before, meaning it already exists on disk.
    Else
        
        Dim dstFilename As String
        
        'PhotoDemon supports two different save modes (controlled via the Tools > Options dialog):
        ' 1) Default mode.  When the user clicks "save", overwrite the copy on disk.
        ' 2) "Safe" mode.  When the user clicks "save", save a new copy of the image, auto-incremented with a trailing number.
        '    (e.g. old copies are never overwritten).
        Dim safeSaveModeActive As Boolean
        safeSaveModeActive = (UserPrefs.GetPref_Long("Saving", "Overwrite Or Copy", 0) <> 0)
        
        If safeSaveModeActive Then
        
            'File name incrementation requires help from an outside function.  We must pass it the folder,
            ' filename, and extension we want it to search against.
            Dim tmpFolder As String, tmpFilename As String, tmpExtension As String
            tmpFolder = Files.FileGetPath(srcImage.ImgStorage.GetEntry_String("CurrentLocationOnDisk", vbNullString))
            If (LenB(srcImage.ImgStorage.GetEntry_String("OriginalFileName", vbNullString)) = 0) Then srcImage.ImgStorage.AddEntry "OriginalFileName", g_Language.TranslateMessage("New image")
            tmpFilename = srcImage.ImgStorage.GetEntry_String("OriginalFileName", vbNullString)
            tmpExtension = srcImage.ImgStorage.GetEntry_String("OriginalFileExtension", vbNullString)
            
            'Now, call the incrementFilename function to find a unique filename of the "filename (n+1)" variety
            dstFilename = tmpFolder & Files.IncrementFilename(tmpFolder, tmpFilename, tmpExtension) & "." & tmpExtension
        
        Else
            dstFilename = srcImage.ImgStorage.GetEntry_String("CurrentLocationOnDisk", vbNullString)
        End If
        
        'New to v7.0 is the way save option dialogs work.  PD's primary save function is now responsible for
        ' displaying save dialogs. (We can forcibly request a dialog, as we do in the "Save As" function,
        ' but in this function, we leave it up to the primary save function to determine if a dialog is necessary.)
        MenuSave = PhotoDemon_SaveImage(srcImage, dstFilename, False)
        
    End If

End Function

'Subroutine for displaying a "save" common dialog, then saving an image to the specified file
Public Function MenuSaveAs(ByRef srcImage As pdImage) As Boolean
    
    If (srcImage Is Nothing) Then Exit Function
    
    Dim saveFileDialog As pdOpenSaveDialog
    Set saveFileDialog = New pdOpenSaveDialog
    
    'Prior to showing the "save image" dialog, we need to determine three things:
    ' 1) An initial folder
    ' 2) What file format to suggest
    ' 3) What filename to suggest (*without* a file extension)
    ' 4) What filename + extension to suggest, based on the results of 2 and 3
    
    'Each of these will be handled in turn
    
    '1) Determine an initial folder.  If the user has saved a file before, we'll use their export
    '   preference to determine what folder we suggest (either the current image's folder, or their
    '   last-used path.)
    '
    '   If, however, the user has *not* saved a file before, we will always use the current image
    '   path (if one exists), or the default preferences engine path if this is e.g. a clipboard
    '   image with no saved path (the preferences engine defaults to the user's Pictures folder.)
    
    'Before doing anything, figure out if the current image even has a useable path; if it doesn't,
    ' we need to adjust behavior
    Dim testPath As String, pathIsUsable As Boolean
    testPath = srcImage.ImgStorage.GetEntry_String("CurrentLocationOnDisk", vbNullString)
    
    'Test the path's existence (important when running PD from a removeable drive)
    pathIsUsable = (LenB(testPath) <> 0)
    If pathIsUsable Then
        testPath = Files.FileGetPath(testPath)
        pathIsUsable = Files.PathExists(testPath, False)
    End If
        
    Dim initialSaveFolder As String
    If UserPrefs.GetPref_Boolean("Saving", "Has Saved A File", True) Then
        
        'Check user preference for default folder behavior
        If UserPrefs.GetPref_Boolean("Saving", "Use Last Folder", False) Then
            initialSaveFolder = UserPrefs.GetPref_String("Paths", "Save Image", vbNullString)
        
        'If the current image has a useable path, use it; otherwise, default to the last-used path
        Else
            If pathIsUsable Then
                initialSaveFolder = testPath
            Else
                initialSaveFolder = UserPrefs.GetPref_String("Paths", "Save Image", vbNullString)
            End If
        End If
        
    Else
        
        'If the current image has a usable path, default to it; otherwise, grab the default value
        ' from the preference's file (typically the active user's Pictures folder)
        If pathIsUsable Then
            initialSaveFolder = testPath
        Else
            initialSaveFolder = UserPrefs.GetPref_String("Paths", "Save Image", vbNullString)
        End If
    
    End If
    
    '2) What file format to suggest.  There is a user preference for persistently defaulting *not* to the
    ' current image's format, but to the last format used in the Save screen.  (This is useful when
    ' mass-converting RAW files to JPEG, for example.)
    '
    ' If that preference is selected, it takes precedence UNLESS the user has not yet saved any images,
    ' in which case we default to the standard method (of using heuristics on the current image,
    ' and suggesting the most appropriate format accordingly).
    Dim cdFormatIndex As Long
    Dim suggestedSaveFormat As PD_IMAGE_FORMAT, suggestedFileExtension As String
    
    If (UserPrefs.GetPref_Long("Saving", "Suggested Format", 0) = 1) And (g_LastSaveFilter <> -1) Then
        cdFormatIndex = g_LastSaveFilter
        suggestedSaveFormat = ImageFormats.GetOutputPDIF(cdFormatIndex - 1)
        suggestedFileExtension = ImageFormats.GetExtensionFromPDIF(suggestedSaveFormat)
        
    'The user's preference is the default value (0) or no previous saves have occurred, meaning we need to suggest a Save As format based
    ' on the current image contents.  This is a fairly complex process, so we offload it to a separate function.
    Else
        suggestedSaveFormat = GetSuggestedSaveFormatAndExtension(srcImage, suggestedFileExtension)
        
        'Now that we have a suggested save format, we need to convert that into its matching Common Dialog filter index.
        ' (Note that the common dialog filter is 1-based, so we manually increment the retrieved index.)
        cdFormatIndex = ImageFormats.GetIndexOfOutputPDIF(suggestedSaveFormat) + 1
    End If
    
    '3) What filename to suggest.  This value is pulled from the image storage object; if this file came from a non-file location
    '   (like the clipboard), that function will have supplied a meaningful name at load-time.  Note that we have to supply a non-null
    '   string to the common dialog function for it to work, so some kind of name needs to be suggested.
    Dim suggestedFilename As String
    suggestedFilename = srcImage.ImgStorage.GetEntry_String("OriginalFileName", vbNullString)
    If (LenB(suggestedFilename) = 0) Then suggestedFilename = g_Language.TranslateMessage("New image")
    
    '4) What filename + extension to suggest, based on the results of 2 and 3.  Most programs would just toss together the
    ' calculated filename + extension, but I like PD to be a bit smarter.  What we're going to do next is scan the default output
    ' folder to see if any files already match this name and extension.  If they do, we're going to append a number to the end of
    ' the filename, e.g. "New Image (2)", and we're going to auto-increment that number until we find a number that isn't in use.
    ' (If auto-incrementing isn't necessary, this function will return the filename we pass it, as-is.)
    '
    'Note that this behavior can be toggled via Tools > Options, to enable "normal" Save As behavior (defaulting to
    ' the current filename, if any).
    Dim sFile As String
    If UserPrefs.GetPref_Boolean("Saving", "save-as-autoincrement", True) Then
        sFile = initialSaveFolder & IncrementFilename(initialSaveFolder, suggestedFilename, suggestedFileExtension)
    Else
        sFile = initialSaveFolder & suggestedFilename
    End If
    
    'With all our inputs complete, we can finally raise the damn common dialog
    If saveFileDialog.GetSaveFileName(sFile, , True, ImageFormats.GetCommonDialogOutputFormats, cdFormatIndex, initialSaveFolder, g_Language.TranslateMessage("Save an image"), ImageFormats.GetCommonDialogDefaultExtensions, FormMain.hWnd) Then
        
        'The common dialog results affect two different objects:
        ' 1) the current image (which needs to store things like the format the user chose)
        ' 2) the global user preferences manager (which needs to remember things like the output folder, so we can remember it)
        
        'Store all image-level attributes
        srcImage.SetCurrentFileFormat ImageFormats.GetOutputPDIF(cdFormatIndex - 1)
        
        'Store all global-preference attributes
        g_LastSaveFilter = cdFormatIndex
        UserPrefs.SetPref_Long "Core", "Last Save Filter", g_LastSaveFilter
        UserPrefs.SetPref_String "Paths", "Save Image", Files.FileGetPath(sFile)
        UserPrefs.SetPref_Boolean "Saving", "Has Saved A File", True
        
        'Our work here is done!  Transfer control to the core SaveImage routine, which will handle the actual export process.
        MenuSaveAs = PhotoDemon_SaveImage(srcImage, sFile, True)
        
    Else
        MenuSaveAs = False
    End If
    
End Function

Private Function GetSuggestedSaveFormatAndExtension(ByRef srcImage As pdImage, ByRef dstSuggestedExtension As String) As PD_IMAGE_FORMAT
    
    'First, see if the image has a file format already.  If it does, we need to suggest that preferentially.
    GetSuggestedSaveFormatAndExtension = srcImage.GetCurrentFileFormat
    
    'One caveat here is if the image already has a format *but* PhotoDemon can't export that format.
    ' If that happens, treat the image as if has never been saved at all (and use heuristics to suggest
    ' a most-appropriate format).
    If (ImageFormats.GetIndexOfOutputPDIF(GetSuggestedSaveFormatAndExtension) < 0) Then GetSuggestedSaveFormatAndExtension = PDIF_UNKNOWN
    
    'For unknown formats, use heuristics to suggest an appropriate output format.
    If (GetSuggestedSaveFormatAndExtension = PDIF_UNKNOWN) Then
    
        'This image must have come from a source where the best save format isn't clear (like a generic clipboard DIB).
        ' As such, we need to suggest an appropriate format.
        
        'Start with the most obvious criteria: does the image have multiple layers?  If so, PDI is best.
        If (srcImage.GetNumOfLayers > 1) Then
            GetSuggestedSaveFormatAndExtension = PDIF_PDI
        Else
        
            'Query the only layer in the image.  If it has meaningful alpha values, we'll suggest PNG; otherwise, JPEG.
            If DIBs.IsDIBAlphaBinary(srcImage.GetActiveDIB, False) Then
                GetSuggestedSaveFormatAndExtension = PDIF_JPEG
            Else
                GetSuggestedSaveFormatAndExtension = PDIF_PNG
            End If
        
        End If
        
        'Also return a proper extension that matches the selected format
        dstSuggestedExtension = ImageFormats.GetExtensionFromPDIF(GetSuggestedSaveFormatAndExtension)
        
    'If the image already has a format, let's reuse its existing file extension instead of suggesting a new one.
    ' This is relevant for formats with ill-defined extensions, like JPEG (e.g. JPE, JPG, JPEG)
    Else
        dstSuggestedExtension = srcImage.ImgStorage.GetEntry_String("OriginalFileExtension")
        If (LenB(dstSuggestedExtension) = 0) Then dstSuggestedExtension = ImageFormats.GetExtensionFromPDIF(GetSuggestedSaveFormatAndExtension)
    End If
            
End Function

'Save a lossless copy of the current image.  I've debated a lot of small details about how to best implement this (e.g. how to
' "most intuitively" implement this), and I've settled on the following:
' 1) Save the copy to the same folder as the current image (if available).  If it's not available, we have no choice but to
'     prompt for a folder.
' 2) Use PDI format (obviously).
' 3) Update the Recent Files list with the saved copy.  If we don't do this, the user has no way of knowing what save settings
'     we've used (filename, location, etc)
' 4) Increment the filename automatically.  Saving a copy does not overwrite old copies.  This is important.
Public Function MenuSaveLosslessCopy(ByRef srcImage As pdImage) As Boolean

    'First things first: see if the image currently exists on-disk.  If it doesn't, we have no choice but to provide a save
    ' prompt.
    If (LenB(srcImage.ImgStorage.GetEntry_String("CurrentLocationOnDisk", vbNullString)) = 0) Then
        
        'TODO: make this a dialog with a "check to remember" option.  I'm waiting on this because I want a generic solution
        '       for these types of dialogs, because they would be helpful in many places throughout PD.
        PDMsgBox "Before lossless copies can be saved, you must save this image at least once." & vbCrLf & vbCrLf & "Lossless copies will be saved to the same folder as this initial image save.", vbExclamation Or vbOKOnly, "Initial save required"
        
        'This image hasn't been saved before.  Launch the Save As... dialog, and wait for it to return.
        MenuSaveLosslessCopy = MenuSaveAs(srcImage)
        
        'If the user canceled, abandon ship
        If (Not MenuSaveLosslessCopy) Then Exit Function
        
    End If
    
    'If we made it here, this image has been saved before.  That gives us a folder where we can place our lossless copies.
    Dim dstFilename As String, tmpPathString As String
    
    'Find out where this image's on-disk copy currently lives
    tmpPathString = Files.FileGetPath(srcImage.ImgStorage.GetEntry_String("CurrentLocationOnDisk", vbNullString))
    
    'Next, determine a filename for our lossless copy.  This is currently calculated as the current filename,
    ' auto-incremented to whatever number is available next, with ".pdi" slapped on the end.
    Dim tmpFilename As String
    tmpFilename = srcImage.ImgStorage.GetEntry_String("OriginalFileName", vbNullString)
    dstFilename = tmpPathString & IncrementFilename(tmpPathString, tmpFilename, "pdi") & ".pdi"
    
    'dstFilename now contains the full path and filename where our image copy should go.  Save it!
    Saving.BeginSaveProcess
    MenuSaveLosslessCopy = SavePDI_Image(srcImage, dstFilename, False, cf_Zstd, cf_Zstd, False, True)
        
    'At this point, it's safe to re-enable the main form and restore the default cursor
    Saving.EndSaveProcess
    
    'MenuSaveLosslessCopy will only be true if the save was successful; if it was, add this file to the MRU list.
    If MenuSaveLosslessCopy Then
        g_RecentFiles.AddFileToList dstFilename, srcImage
    Else
        Message "Save canceled."
        PDMsgBox "An unspecified error occurred when attempting to save this image.  Please try saving the image to an alternate format." & vbCrLf & vbCrLf & "If the problem persists, please report it to the PhotoDemon developers via photodemon.org/contact", vbCritical Or vbOKOnly, "Error"
    End If

End Function

'Close the active image
Public Sub MenuClose()
    CanvasManager.FullPDImageUnload PDImages.GetActiveImageID()
End Sub

'Close all active images
Public Sub MenuCloseAll()

    'Note that the user has opted to close ALL open images; this is used by the central image handler to know what kind
    ' of "Unsaved changes" dialog to display.
    g_ClosingAllImages = True
    
    'An external function handles the actual closing process
    If (Not CanvasManager.CloseAllImages()) Then Message vbNullString
    
    'Redraw the screen to match any program state changes
    Interface.SyncInterfaceToCurrentImage
    
    'Reset the "closing all images" flags
    g_ClosingAllImages = False
    g_DealWithAllUnsavedImages = False

End Sub

'Create a new, blank image from scratch.  Incoming parameters must be assembled as XML (via pdSerialize, typically)
Public Function CreateNewImage(Optional ByRef newImageParameters As String) As Boolean
    
    Dim cParams As pdSerialize
    Set cParams = New pdSerialize
    cParams.SetParamString newImageParameters
    
    Dim newWidth As Long, newHeight As Long, newDPI As Double
    Dim newBackgroundType As Long, newBackgroundColor As Long
    
    With cParams
        newWidth = .GetLong("WidthInPixels", g_Displays.GetDesktopWidth)
        newHeight = .GetLong("HeightInPixels", g_Displays.GetDesktopHeight)
        newDPI = .GetLong("DPI", 96&)
        newBackgroundType = .GetLong("BackgroundType", 0)
        newBackgroundColor = .GetLong("OptionalBackcolor", vbBlack)
    End With
    
    'Display a busy cursor and disable user input
    Processor.MarkProgramBusyState True, True
    
    'Create a new pdImage object.
    Dim newImage As pdImage
    PDImages.GetDefaultPDImageObject newImage
    newImage.imageID = PDImages.GetProvisionalImageID()
    
    'We can now address our new image via PDImages.GetActiveImage.  Create a blank layer.
    Dim newLayerID As Long
    newLayerID = newImage.CreateBlankLayer()
    
    'The parameters passed to the new DIB vary according to layer type.  Use the specified type to determine how we
    ' initialize the new layer.
    Dim newBackColor As Long, newBackAlpha As Long
    Select Case newBackgroundType
    
        'Transparent (blank)
        Case 0
            newBackColor = 0
            newBackAlpha = 0
            
        'Black
        Case 1
            newBackColor = RGB(0, 0, 0)
            newBackAlpha = 255
        
        'White
        Case 2
            newBackColor = RGB(255, 255, 255)
            newBackAlpha = 255
        
        'Custom color
        Case 3
            newBackColor = newBackgroundColor
            newBackAlpha = 255
    
    End Select
    
    'Create a matching DIB
    Dim tmpDIB As pdDIB
    Set tmpDIB = New pdDIB
    If tmpDIB.CreateBlank(newWidth, newHeight, 32, newBackColor, newBackAlpha) Then
    
        'Assign the newly created DIB to the layer object
        tmpDIB.SetInitialAlphaPremultiplicationState True
        newImage.GetLayerByID(newLayerID).InitializeNewLayer PDL_Image, g_Language.TranslateMessage("background"), tmpDIB
        
        'Update the pdImage container to be the same size as its (newly created) base layer
        newImage.UpdateSize
        
        'Assign the requested DPI to the new image
        newImage.SetDPI newDPI, newDPI
        
        'Reset any/all file format markers; at save-time, PD will run heuristics on the image's contents and suggest a
        ' better format accordingly.
        newImage.SetOriginalFileFormat PDIF_UNKNOWN
        newImage.SetCurrentFileFormat PDIF_UNKNOWN
        newImage.SetOriginalColorDepth 32
        newImage.SetOriginalGrayscale False
        newImage.SetOriginalAlpha True
        
        'Similarly, because this image does not exist on the user's hard-drive, we want to force use of a full Save As dialog
        ' in the future.  (PD detects this state if a pdImage object does not supply an on-disk location)
        newImage.ImgStorage.AddEntry "CurrentLocationOnDisk", vbNullString
        newImage.ImgStorage.AddEntry "OriginalFileName", g_Language.TranslateMessage("New image")
        newImage.ImgStorage.AddEntry "OriginalFileExtension", vbNullString
        newImage.SetSaveState False, pdSE_AnySave
        
        'Add the finished image to the central collection, and ensure that the newly created layer is the active layer
        PDImages.AddImageToCentralCollection newImage
        Layers.SetActiveLayerByID newLayerID, False, False
        
        'Use the Image Importer engine to prepare a bunch of default viewport settings for us.  (Because this new image
        ' doesn't exist on-disk yet, note that we pass a null-string for the filename, and we explicitly request that
        ' the engine does *not* add this entry to the Recent Files list yet.)
        ImageImporter.ApplyPostLoadUIChanges vbNullString, newImage, False
        
        'Force an immediate Undo/Redo write to file.  This serves multiple purposes: it is our baseline for calculating future
        ' Undo/Redo diffs, and it can be used to recover the original file if something goes wrong before the user performs a
        ' manual save (e.g. AutoSave).
        Dim tmpProcData As PD_ProcessCall
        With tmpProcData
            .pcID = g_Language.TranslateMessage("Original image")
            .pcParameters = vbNullString
            .pcUndoType = UNDO_Everything
            .pcRaiseDialog = False
            .pcRecorded = True
        End With
        
        newImage.UndoManager.CreateUndoData tmpProcData
        
        'Synchronize all interface elements to match the newly loaded image(s), including various layer-specific settings
        Interface.SyncInterfaceToCurrentImage
        Processor.SyncAllGenericLayerProperties PDImages.GetActiveImage.GetActiveLayer
        Processor.SyncAllTextLayerProperties PDImages.GetActiveImage.GetActiveLayer
        
        'Unlock the program's UI and activate the finished image
        Processor.MarkProgramBusyState False, True
        CanvasManager.ActivatePDImage PDImages.GetActiveImageID(), "LoadFileAsNewImage"
        
        'Report success!
        CreateNewImage = True
        
    Else
        CreateNewImage = False
        PDMsgBox "Unfortunately, this PC does not have enough memory to create a %1x%2 image.  Please reduce the requested size and try again.", vbExclamation Or vbOKOnly, "Image too large", newWidth, newHeight
    End If
    
    'Re-enable the main form
    Processor.MarkProgramBusyState False
    
    'Synchronize all interface elements to match the newly created image
    Interface.SyncInterfaceToCurrentImage
    
End Function
