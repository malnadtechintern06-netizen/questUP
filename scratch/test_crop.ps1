Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile('c:\Users\DELL\Desktop\questUP\assets\images\hero_card.png')
Write-Host "Original: $($bmp.Width) x $($bmp.Height)"

# Check pixel colors at y=78, 80, 83
for ($y = 70; $y -le 90; $y += 2) {
    $c = $bmp.GetPixel(230, $y)
    Write-Host "y=$y G=$($c.G) B=$($c.B)"
}

# Check pixel colors at bottom y=930 to 950
for ($y = 930; $y -le 950; $y += 2) {
    $c = $bmp.GetPixel(230, $y)
    Write-Host "y=$y G=$($c.G) B=$($c.B)"
}
$bmp.Dispose()
