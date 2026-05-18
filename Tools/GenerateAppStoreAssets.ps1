Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$outputRoot = Join-Path $root "AppStoreAssets"
$iphoneDir = Join-Path $outputRoot "iPhone-6.5"
$ipadDir = Join-Path $outputRoot "iPad-13"
New-Item -ItemType Directory -Force -Path $iphoneDir, $ipadDir | Out-Null

function New-Brush($r, $g, $b) {
    return New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($r, $g, $b))
}

function New-PenColor($r, $g, $b, $width) {
    return New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($r, $g, $b)), $width
}

function Draw-RoundedRect($g, $brush, $x, $y, $w, $h, $r) {
    if ($r -le 0) {
        $g.FillRectangle($brush, $x, $y, $w, $h)
        return
    }

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    $path.AddArc($x, $y, $d, $d, 180, 90)
    $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $path.CloseFigure()
    $g.FillPath($brush, $path)
    $path.Dispose()
}

function Draw-Text($g, $text, $x, $y, $w, $h, $size, $style, $brush, $align = "Near") {
    $font = New-Object System.Drawing.Font "Arial", $size, $style, ([System.Drawing.GraphicsUnit]::Pixel)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::$align
    $format.LineAlignment = [System.Drawing.StringAlignment]::Near
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisWord
    $format.FormatFlags = [System.Drawing.StringFormatFlags]::LineLimit
    $rect = New-Object System.Drawing.RectangleF $x, $y, $w, $h
    $g.DrawString($text, $font, $brush, $rect, $format)
    $format.Dispose()
    $font.Dispose()
}

function Draw-Badge($g, $text, $x, $y, $w, $colorBrush, $textBrush) {
    Draw-RoundedRect $g $colorBrush $x $y $w 54 27
    Draw-Text $g $text ($x + 22) ($y + 13) ($w - 44) 32 24 ([System.Drawing.FontStyle]::Bold) $textBrush "Center"
}

function Draw-PhoneChrome($g, $width, $height, $title) {
    $navy = New-Brush 10 31 61
    $white = New-Brush 255 255 255
    $light = New-Brush 244 247 250
    $orange = New-Brush 232 92 33

    $g.FillRectangle($light, 0, 0, $width, $height)
    Draw-RoundedRect $g $navy 0 0 $width 360 0
    Draw-Text $g "StormClaim AI" 72 86 ($width - 144) 52 36 ([System.Drawing.FontStyle]::Bold) $white
    Draw-Text $g "Storm damage documentation, evidence, and reports" 72 142 ($width - 144) 46 24 ([System.Drawing.FontStyle]::Regular) $white
    Draw-RoundedRect $g $orange 72 212 230 66 18
    Draw-Text $g "Mock AI On" 104 229 166 30 24 ([System.Drawing.FontStyle]::Bold) $white "Center"
    Draw-Text $g $title 72 292 ($width - 144) 68 46 ([System.Drawing.FontStyle]::Bold) $white
}

function Draw-TabletChrome($g, $width, $height, $title) {
    $navy = New-Brush 10 31 61
    $white = New-Brush 255 255 255
    $light = New-Brush 244 247 250
    $orange = New-Brush 232 92 33

    $g.FillRectangle($light, 0, 0, $width, $height)
    Draw-RoundedRect $g $navy 0 0 $width 310 0
    Draw-Text $g "StormClaim AI" 96 76 ($width - 192) 58 44 ([System.Drawing.FontStyle]::Bold) $white
    Draw-Text $g "Professional storm damage documentation for property and claim-support teams" 96 142 ($width - 192) 44 26 ([System.Drawing.FontStyle]::Regular) $white
    Draw-RoundedRect $g $orange ($width - 350) 78 230 64 18
    Draw-Text $g "Mock AI On" ($width - 326) 94 182 32 24 ([System.Drawing.FontStyle]::Bold) $white "Center"
    Draw-Text $g $title 96 236 ($width - 192) 64 48 ([System.Drawing.FontStyle]::Bold) $white
}

function Draw-Card($g, $x, $y, $w, $h) {
    $white = New-Brush 255 255 255
    Draw-RoundedRect $g $white $x $y $w $h 24
}

function Draw-PhotoMock($g, $x, $y, $w, $h, $label) {
    $sky = New-Brush 206 222 232
    $roof = New-Brush 73 84 96
    $dark = New-Brush 31 41 55
    $orange = New-Brush 232 92 33
    Draw-RoundedRect $g $sky $x $y $w $h 18
    $points = [System.Drawing.Point[]]@(
        (New-Object System.Drawing.Point ($x + 40), ($y + [int]($h * 0.62))),
        (New-Object System.Drawing.Point ($x + [int]($w * 0.5)), ($y + [int]($h * 0.34))),
        (New-Object System.Drawing.Point ($x + $w - 40), ($y + [int]($h * 0.62))),
        (New-Object System.Drawing.Point ($x + $w - 70), ($y + $h - 40)),
        (New-Object System.Drawing.Point ($x + 70), ($y + $h - 40))
    )
    $g.FillPolygon($roof, $points)
    for ($i = 0; $i -lt 5; $i++) {
        $g.FillRectangle($dark, ($x + 130 + ($i * 86)), ($y + [int]($h * 0.58) + ($i % 2 * 18)), 58, 14)
    }
    Draw-RoundedRect $g $orange ($x + 32) ($y + 32) 260 54 20
    $white = New-Brush 255 255 255
    Draw-Text $g $label ($x + 56) ($y + 45) 212 30 22 ([System.Drawing.FontStyle]::Bold) $white "Center"
}

function Draw-Stats($g, $x, $y, $w) {
    $navy = New-Brush 10 31 61
    $muted = New-Brush 91 103 118
    $orange = New-Brush 232 92 33
    $green = New-Brush 23 135 84
    $cardW = [int](($w - 36) / 2)
    $labels = @(
        @("12", "Recent Cases", $orange),
        @("4", "Urgent Damage", (New-Brush 203 50 50)),
        @("9", "Reports Generated", $green),
        @("Pro", "Subscription", $navy)
    )
    for ($i = 0; $i -lt 4; $i++) {
        $cx = $x + (($i % 2) * ($cardW + 36))
        $cy = $y + ([Math]::Floor($i / 2) * 170)
        Draw-Card $g $cx $cy $cardW 138
        Draw-Text $g $labels[$i][0] ($cx + 30) ($cy + 24) ($cardW - 60) 46 38 ([System.Drawing.FontStyle]::Bold) $labels[$i][2]
        Draw-Text $g $labels[$i][1] ($cx + 30) ($cy + 78) ($cardW - 60) 34 22 ([System.Drawing.FontStyle]::Regular) $muted
    }
}

function Draw-Checklist($g, $items, $x, $y, $w) {
    $navy = New-Brush 10 31 61
    $muted = New-Brush 91 103 118
    $orange = New-Brush 232 92 33
    $rowY = $y
    foreach ($item in $items) {
        $g.FillEllipse($orange, $x, ($rowY + 7), 22, 22)
        Draw-Text $g $item ($x + 42) $rowY ($w - 42) 38 24 ([System.Drawing.FontStyle]::Regular) $muted
        $rowY += 48
    }
}

function New-Screenshot($path, $width, $height, $title, $variant, $tablet = $false) {
    $bmp = New-Object System.Drawing.Bitmap $width, $height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

    $navy = New-Brush 10 31 61
    $muted = New-Brush 91 103 118
    $orange = New-Brush 232 92 33
    $red = New-Brush 203 50 50
    $yellow = New-Brush 245 180 44
    $green = New-Brush 23 135 84
    $white = New-Brush 255 255 255

    if ($tablet) {
        Draw-TabletChrome $g $width $height $title
        $left = 96
        $top = 380
        $contentW = $width - 192
    } else {
        Draw-PhoneChrome $g $width $height $title
        $left = 72
        $top = 430
        $contentW = $width - 144
    }

    switch ($variant) {
        "dashboard" {
            Draw-Card $g $left $top $contentW 300
            Draw-Text $g "New Storm Claim Case" ($left + 42) ($top + 38) ($contentW - 84) 52 36 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Create a case, add property details, attach photos, and generate a professional PDF." ($left + 42) ($top + 104) ($contentW - 84) 92 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-RoundedRect $g $orange ($left + 42) ($top + 212) 320 64 20
            Draw-Text $g "Start Case" ($left + 74) ($top + 229) 256 30 24 ([System.Drawing.FontStyle]::Bold) $white "Center"
            Draw-Stats $g $left ($top + 350) $contentW
            Draw-Card $g $left ($top + 740) $contentW 230
            Draw-Text $g "Recent Case" ($left + 42) ($top + 772) 320 34 28 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "42 Harbour View, Cardiff" ($left + 42) ($top + 820) 600 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Badge $g "Urgent" ($left + $contentW - 210) ($top + 790) 150 $red $white
        }
        "case" {
            Draw-Card $g $left $top $contentW 350
            Draw-Text $g "Property details" ($left + 42) ($top + 38) ($contentW - 84) 42 34 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Client: Morgan Property Group" ($left + 42) ($top + 104) ($contentW - 84) 34 25 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Storm date: 15 May 2026" ($left + 42) ($top + 152) ($contentW - 84) 34 25 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Storm type: Wind" ($left + 42) ($top + 200) ($contentW - 84) 34 25 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Policy/reference optional" ($left + 42) ($top + 248) ($contentW - 84) 34 25 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Card $g $left ($top + 400) $contentW 180
            Draw-Text $g "Safety-first workflow" ($left + 42) ($top + 432) ($contentW - 84) 42 32 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Users should not climb roofs or take unsafe photos. Emergency issues should be handled by professionals." ($left + 42) ($top + 488) ($contentW - 84) 70 24 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Checklist $g @("Not insurance advice", "Not legal advice", "AI findings require professional review") $left ($top + 650) $contentW
        }
        "photos" {
            Draw-PhotoMock $g $left $top $contentW 470 "Roof surface"
            Draw-Card $g $left ($top + 520) $contentW 190
            Draw-Text $g "Photo evidence organizer" ($left + 42) ($top + 552) ($contentW - 84) 40 32 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Label roof surface, missing shingles, gutter damage, flashing, ceiling stains, debris, and more." ($left + 42) ($top + 606) ($contentW - 84) 64 24 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Card $g $left ($top + 760) $contentW 150
            Draw-Badge $g "Relevant" ($left + 42) ($top + 804) 170 $green $white
            Draw-Badge $g "Needs Review" ($left + 236) ($top + 804) 220 $yellow $navy
            Draw-Badge $g "Urgent" ($left + 482) ($top + 804) 150 $red $white
        }
        "ai" {
            Draw-PhotoMock $g $left $top $contentW 360 "Missing shingles"
            Draw-Card $g $left ($top + 410) $contentW 330
            Draw-Text $g "Possible wind-related displacement" ($left + 42) ($top + 444) ($contentW - 300) 78 32 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Badge $g "High" ($left + $contentW - 190) ($top + 450) 130 $orange $white
            Draw-Text $g "Visible gaps appear consistent with possible roof covering displacement. Cause cannot be confirmed from the image alone." ($left + 42) ($top + 540) ($contentW - 84) 90 25 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Suggested action: qualified roof inspection and temporary weatherproofing if water entry is possible." ($left + 42) ($top + 654) ($contentW - 84) 70 24 ([System.Drawing.FontStyle]::Bold) $muted
            Draw-Card $g $left ($top + 790) $contentW 160
            Draw-Text $g "User approval toggle keeps every AI finding under human review." ($left + 42) ($top + 836) ($contentW - 84) 64 26 ([System.Drawing.FontStyle]::Regular) $muted
        }
        "report" {
            Draw-Card $g $left $top $contentW 680
            Draw-Text $g "Storm Damage Documentation Report" ($left + 42) ($top + 42) ($contentW - 84) 82 36 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Property details" ($left + 42) ($top + 148) 420 36 28 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Storm event details" ($left + 42) ($top + 206) 420 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Inspection summary" ($left + 42) ($top + 258) 420 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Damage evidence and photo log" ($left + 42) ($top + 310) 520 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Severity breakdown" ($left + 42) ($top + 362) 420 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Repair priority list" ($left + 42) ($top + 414) 420 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-Text $g "Insurance disclaimer" ($left + 42) ($top + 466) 420 36 26 ([System.Drawing.FontStyle]::Regular) $muted
            Draw-RoundedRect $g $orange ($left + 42) ($top + 560) 360 70 20
            Draw-Text $g "Export PDF" ($left + 84) ($top + 578) 276 34 26 ([System.Drawing.FontStyle]::Bold) $white "Center"
            Draw-Card $g $left ($top + 740) $contentW 190
            Draw-Text $g "Professional exports" ($left + 42) ($top + 774) ($contentW - 84) 40 32 ([System.Drawing.FontStyle]::Bold) $navy
            Draw-Text $g "Pro adds custom logo support. Business adds branded cover pages and claim-support formatting." ($left + 42) ($top + 832) ($contentW - 84) 70 24 ([System.Drawing.FontStyle]::Regular) $muted
        }
    }

    $footerY = $height - 220
    Draw-Text $g "Documentation support only. Not insurance, legal, structural, engineering, or certified inspection advice." 72 $footerY ($width - 144) 90 22 ([System.Drawing.FontStyle]::Regular) $muted "Center"

    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
}

$screens = @(
    @("01-dashboard.png", "Document storm damage cases", "dashboard"),
    @("02-new-case.png", "Capture property and storm details", "case"),
    @("03-photo-evidence.png", "Organize photo evidence", "photos"),
    @("04-ai-findings.png", "Review cautious AI findings", "ai"),
    @("05-pdf-report.png", "Export professional PDF reports", "report")
)

foreach ($screen in $screens) {
    New-Screenshot (Join-Path $iphoneDir $screen[0]) 1242 2688 $screen[1] $screen[2] $false
    New-Screenshot (Join-Path $ipadDir $screen[0]) 2048 2732 $screen[1] $screen[2] $true
}

Write-Host "Generated App Store assets in $outputRoot"
