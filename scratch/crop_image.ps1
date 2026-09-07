Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile('c:\Users\DELL\Desktop\questUP\assets\images\hero_card.png')
# Crop rectangle: x=0, y=74, w=459, h=874
$rect = New-Object System.Drawing.Rectangle(0, 74, 459, 874)
$cropped = $bmp.Clone($rect, $bmp.PixelFormat)
$cropped.Save('c:\Users\DELL\Desktop\questUP\scratch\hero_card_cropped.png', [System.Drawing.Imaging.ImageFormat]::Png)
Write-Host "Cropped dimensions: $($cropped.Width) x $($cropped.Height), AspectRatio: $($cropped.Width / $cropped.Height)"
$cropped.Dispose()
$bmp.Dispose()
