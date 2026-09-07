Add-Type -AssemblyName System.Drawing
$bmp = [System.Drawing.Bitmap]::FromFile('c:\Users\DELL\Desktop\questUP\assets\images\hero_card.png')

# Find top cyan border
for ($y = 0; $y -le 300; $y++) {
    $c = $bmp.GetPixel(230, $y)
    if ($c.G -gt 100 -and $c.B -gt 150) {
        Write-Host "Top cyan border at y=$y"
        break
    }
}

# Find left and right cyan borders
for ($x = 0; $x -le 200; $x++) {
    $c = $bmp.GetPixel($x, 500)
    if ($c.G -gt 100 -and $c.B -gt 150) {
        Write-Host "Left cyan border at x=$x"
        break
    }
}
for ($x = 458; $x -ge 250; $x--) {
    $c = $bmp.GetPixel($x, 500)
    if ($c.G -gt 100 -and $c.B -gt 150) {
        Write-Host "Right cyan border at x=$x"
        break
    }
}

# Scan top area for QuestUP logo
for ($y = 80; $y -le 200; $y += 10) {
    $brightCount = 0
    for ($x = 30; $x -le 250; $x += 5) {
        $c = $bmp.GetPixel($x, $y)
        if (($c.R + $c.G + $c.B) -gt 350) { $brightCount++ }
    }
    Write-Host "Logo area y=$y bright=$brightCount"
}

$bmp.Dispose()
