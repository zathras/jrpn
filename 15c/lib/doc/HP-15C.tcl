# ------------------------------------------------------------------------------
#
#                      H E W L E T T - P A C K A R D  15C
#
#                  A simulator for Windows, Linux and macOS
#
#                          (c) 1997-2023 Torsten Manz
#
# ------------------------------------------------------------------------------
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, see <https://www.gnu.org/licenses/>
#
# ------------------------------------------------------------------------------

package require Tk
lappend auto_path [file dirname [info script]]/lib

package require msgcat
namespace import ::msgcat::*
package require math
package require math::fuzzy
namespace import math::fuzzy::*
package require html
package require history
package require prdoc
package require hplcd
package require s56b
package require matrix
package require DM15

# ------------------------------------------------------------------------------
# Hide main toplevel until everything is ready
wm withdraw .

# ------------------------------------------------------------------------------
# Application data: All non persistent parameters

array set APPDATA {
  appname "HP-15C"
  title "H E W L E T T \u00B7 P A C K A R D 15C"
  brand "HEWLETT\u00B7PACKARD"
  model "HEWLETT\u00B7PACKARD 15C"
  build "6304G0"
  version "4.5.RC1"
  memfile "HP-15C.mme"
  hstfile "HP-15C.hst"
  copyright "COPYRIGHT \u00A9 1997-2023, Torsten Manz"
  homepage "https://hp-15c.homepage.t-online.de"
  mintclversion 8.6.6
  control "Control"
  option "Alt"
  hp "%"
  15C "&"
  PrefIcons 1
}

set APPDATA(SerialNo) "$APPDATA(build)[string map {. {}} $APPDATA(version)]"
set APPDATA(basedir) [file dirname [info script]]
set APPDATA(locale) [mclocale]

# Load language according to current locale
if {[mcload "$APPDATA(basedir)/msgs"] == 0} {
  tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
    -message "Could not find a valid language file."
  exit
}

# ------------------------------------------------------------------------------
# Check on required minimum Tcl/TK version and ressources

option add *Dialog.msg.font "Helvetica 10" userDefault
option add *Dialog.msg.wrapLength 600 userDefault

if {[package vcompare [info patchlevel] $APPDATA(mintclversion)] < 0} {
  tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
    -message [mc app.mintclver $APPDATA(mintclversion)]
  exit
}

set APPDATA(tkpath) [expr ![catch {package require tkpath}]]
set APPDATA(hp15cfont) \
  [expr [lsearch -regexp -nocase [font families] {HP15C *Simulator *Font}] > 0]

if {!$APPDATA(hp15cfont) &&
  !([tk windowingsystem] eq "win32" && $APPDATA(tkpath))} {
  tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
    -message [mc app.installfont]
  exit
}

# ------------------------------------------------------------------------------
# Default program settings

array set HP15_DEF {
  seqindicator 0
  authorship ""
  breakstomenu 1
  browser ""
  clpbrdc 0
  clpbrdprgm 1
  combkey "+"
  dataregs 19
  delay 0
  docuonload 1
  docuwarn 1
  dotmarks 1
  extendedchars 1
  flash 200
  freebytes 0
  gsbmax 7
  histsize 10
  histfullpath 0
  html_en 1
  html_indent 1
  html_1column 0
  html_bwkeys 0
  lang "-"
  matseparator semicolon
  matstyle rowcol
  matcascade 1
  mnemonics 1
  osxmenus 1
  sortgsb 0
  pause 1000
  prgmcoloured 1
  prgmmenubreak 30
  prgmname ""
  poolregsfree 46
  prgmregs 0
  prgmstounicode 1
  saveonexit 1
  savewinpos 0
  secondaryclick 1
  secondaryhilight 1
  showmenu 0
  stomenudesc 0
  strictHP15 0
  usetkpath 0
  totregs 64
  winpos ""
  wm_top 0
}
array set HP15 [array get HP15_DEF]

# DM-15 Settings
array set DM15 {
  dm15cc 0
  dm15cc_port ""
  timeout 2
  interactive 1
  spdriver native
  r_flags 0
  r_prgm 1
  r_stack 0
  r_sto 0
  r_mat 0
  w_flags 0
  w_prgm 1
  w_stack 0
  w_sto 0
  w_mat 0
}

set DM15timefmtd ""
set DM15synching 0

# Used by Preferences dialogue to hold changed values until Ok or Apply.
array set hp15tmp {}
array set dm15tmp {}
array set prdoctmp {}

set hp15tmplang ""

set filehist [::history::create 10]

# ------------------------------------------------------------------------------
# Platform independent interface settings

array set LAYOUT {
  display #9E9E87
  display_outer_frame #ECF0F0
  display_inner_frame #D9DEDD
  display_top_frame #E2E5E5
  keypad_bg #484848
  button_bg #393939
  button_bg_l #282828
  button_sep #434343
  button_fg white
  keypad_frame #E0E0E0
  keypad_groove #101010
  fbutton_bg #E1A83E
  gbutton_bg #6CB7BD
}

# Predefined, well adjusted font sets
set FONTSET {
  { x11 "DejaVu fonts, small" dv1 {
    FnDisplay "{HP15C Simulator Font} 21"
    FnStatus "{DejaVu Sans} 8"
    FnButton "{DejaVu Sans} 10 bold"
    FnFGBtn "{DejaVu Sans} 7"
    FnClear "{DejaVu Sans} 6"
    FnBrand "{DejaVu Sans} 7"
    FnLogo1 "{HP15C Simulator Font} 17"
    FnLogo2 "{HP15C Simulator Font} 10"
    FnMenu HP15C_Menu_Font
  }}
  { x11 "DejaVu fonts, normal" dv2 {
    FnDisplay "{HP15C Simulator Font} 23"
    FnStatus "{DejaVu Sans} 9"
    FnButton "{DejaVu Sans} 12 bold"
    FnFGBtn "{DejaVu Sans} 8"
    FnClear "{DejaVu Sans} 7"
    FnBrand "{DejaVu Sans} 8 bold"
    FnLogo1 "{HP15C Simulator Font} 18"
    FnLogo2 "{HP15C Simulator Font} 9"
    FnMenu HP15C_Menu_Font
  }}
  { x11 "DejaVu fonts, large" dv3 {
    FnDisplay "{HP15C Simulator Font} 29"
    FnStatus "{DejaVu Sans} 11"
    FnButton "{DejaVu Sans} 14 bold"
    FnFGBtn "{DejaVu Sans} 10"
    FnClear "{DejaVu Sans} 8"
    FnBrand "{DejaVu Sans} 10"
    FnLogo1 "{HP15C Simulator Font} 23"
    FnLogo2 "{HP15C Simulator Font} 14"
    FnMenu HP15C_Menu_Font
  }}
  { x11 "DejaVu fonts, huge" dv4 {
    FnDisplay "{HP15C Simulator Font} 36"
    FnStatus "{DejaVu Sans} 14"
    FnButton "{DejaVu Sans} 18 bold"
    FnFGBtn "{DejaVu Sans} 13"
    FnClear "{DejaVu Sans} 11"
    FnBrand "{DejaVu Sans} 13"
    FnLogo1 "{HP15C Simulator Font} 28"
    FnLogo2 "{HP15C Simulator Font} 15"
    FnMenu HP15C_Menu_Font
  }}
  { x11 "Microsoft fonts, small" ? {
    FnDisplay "{HP15C Simulator Font} 21"
    FnStatus "{Microsoft Sans Serif} 7"
    FnButton "Arial 10 bold"
    FnFGBtn "Arial 7"
    FnClear "Arial 6"
    FnBrand "Arial 8"
    FnLogo1 "{HP15C Simulator Font} 15"
    FnLogo2 "{HP15C Simulator Font} 9"
    FnMenu HP15C_Menu_Font
  }}
  { x11 "Microsoft fonts, normal" ms2 {
    FnDisplay "{HP15C Simulator Font} 23"
    FnStatus "{Microsoft Sans Serif} 8"
    FnButton "Arial 11 bold"
    FnFGBtn "{Microsoft Sans Serif} 8"
    FnClear "Arial 7"
    FnBrand "Arial 8 bold"
    FnLogo1 "{HP15C Simulator Font} 18"
    FnLogo2 "{HP15C Simulator Font} 11"
    FnMenu HP15C_Menu_Font
  }}
  { win32 "Microsoft fonts, small" ms1 {
    FnDisplay "{HP15C Simulator Font} 18"
    FnStatus "{Microsoft Small Fonts} 6"
    FnButton "Arial 9 bold"
    FnFGBtn "{Microsoft Sans Serif} 6"
    FnClear "Tahoma 5"
    FnBrand "Arial 7 bold"
    FnLogo1 "{HP15C Simulator Font} 14"
    FnLogo2 "{HP15C Simulator Font} 8"
    FnMenu HP15C_Menu_Font
  }}
  { win32 "Microsoft fonts, normal" ms2 {
    FnDisplay "{HP15C Simulator Font} 21"
    FnStatus "{Microsoft Sans Serif} 7"
    FnButton "Arial 10 bold"
    FnFGBtn "{Microsoft Sans Serif} 7"
    FnClear "Arial 6"
    FnBrand "Arial 8 bold"
    FnLogo1 "{HP15C Simulator Font} 16"
    FnLogo2 "{HP15C Simulator Font} 9"
    FnMenu HP15C_Menu_Font
  }}
  { win32 "Microsoft fonts, large" ms3 {
    FnDisplay "{HP15C Simulator Font} 25"
    FnStatus "{Microsoft Sans Serif} 8"
    FnButton "Arial 13 bold"
    FnFGBtn "{Microsoft Sans Serif} 9"
    FnClear "Tahoma 7"
    FnBrand "Arial 10"
    FnLogo1 "{HP15C Simulator Font} 20"
    FnLogo2 "{HP15C Simulator Font} 11"
    FnMenu HP15C_Menu_Font
  }}
  { win32 "Microsoft fonts, huge" ms4 {
    FnDisplay "{HP15C Simulator Font} 29"
    FnStatus "{Microsoft Sans Serif} 10"
    FnButton "Arial 14 bold"
    FnFGBtn "Arial 10"
    FnClear "Tahoma 8"
    FnBrand "Arial 11"
    FnLogo1 "{HP15C Simulator Font} 22"
    FnLogo2 "{HP15C Simulator Font} 13"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "DejaVu fonts, small" dv1 {
    FnDisplay "{HP15C Simulator Font} 21"
    FnStatus "{DejaVu Sans} 8"
    FnButton "{DejaVu Sans} 10"
    FnFGBtn "{DejaVu Sans} 7"
    FnClear "{DejaVu Sans} 6"
    FnBrand "{DejaVu Sans} 7"
    FnLogo1 "{HP15C Simulator Font} 16"
    FnLogo2 "{HP15C Simulator Font} 10"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "DejaVu fonts, normal" dv2 {
    FnDisplay "{HP15C Simulator Font} 24"
    FnStatus "{DejaVu Sans} 9"
    FnButton "{DejaVu Sans} 12"
    FnFGBtn "{DejaVu Sans} 9"
    FnClear "{DejaVu Sans} 7"
    FnBrand "{DejaVu Sans} 8"
    FnLogo1 "{HP15C Simulator Font} 19"
    FnLogo2 "{HP15C Simulator Font} 11"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "DejaVu fonts, large" dv3 {
    FnDisplay "{HP15C Simulator Font} 29"
    FnStatus "{DejaVu Sans} 11"
    FnButton "{DejaVu Sans} 14"
    FnFGBtn "{DejaVu Sans} 11"
    FnClear "{DejaVu Sans} 9"
    FnBrand "{DejaVu Sans} 10"
    FnLogo1 "{HP15C Simulator Font} 23"
    FnLogo2 "{HP15C Simulator Font} 14"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "DejaVu fonts, huge" dv4 {
    FnDisplay "{HP15C Simulator Font} 36"
    FnStatus "{DejaVu Sans} 14"
    FnButton "{DejaVu Sans} 18"
    FnFGBtn "{DejaVu Sans} 13"
    FnClear "{DejaVu Sans} 11"
    FnBrand "{DejaVu Sans} 13"
    FnLogo1 "{HP15C Simulator Font} 28"
    FnLogo2 "{HP15C Simulator Font} 18"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "Microsoft fonts, small" ms1 {
    FnDisplay "{HP15C Simulator Font} 25"
    FnStatus "{Microsoft Sans Serif} 9"
    FnButton "Arial 12"
    FnFGBtn "Arial 9"
    FnClear "Tahoma 7"
    FnBrand "Arial 9 bold"
    FnLogo1 "{HP15C Simulator Font} 18"
    FnLogo2 "{HP15C Simulator Font} 11"
    FnMenu HP15C_Menu_Font
  }}
  { aqua "Microsoft fonts, normal" ms2 {
    FnDisplay "{HP15C Simulator Font} 26"
    FnStatus "{Microsoft Sans Serif} 10"
    FnButton "Arial 14"
    FnFGBtn "{Microsoft Sans Serif} 10"
    FnClear "Tahoma 8"
    FnBrand "Arial 10 bold"
    FnLogo1 "{HP15C Simulator Font} 21"
    FnLogo2 "{HP15C Simulator Font} 13"
    FnMenu HP15C_Menu_Font
  }}
}

# Derive menu font from system fixed font
set fnsize [font actual TkFixedFont -size]
# WA-Linux: "font actual" returns "-size 0" for Tk standard fonts on some systems
if {$fnsize <= 0} {
  set fnsize [expr int([font metrics TkFixedFont -linespace]*0.65)]
}
font create HP15C_Menu_Font -family [font actual TkFixedFont -family] \
  -size $fnsize

# Standard fonts for About dialogue
if {[tk windowingsystem] eq "aqua"} {
  font create FnApp -family Arial -size 18 -weight bold
  font create FnAbout -family Arial -size 14 -weight bold
  font create FnWarranty -family Arial -size 11
} else {
  font create FnApp -family Arial -size 12 -weight bold
  font create FnAbout -family Arial -size 10 -weight bold
  font create FnWarranty -family Arial -size 8
}

# ------------------------------------------------------------------------------
# HP-15C help file location
# Differentiate between running from a starpack or from wish
if {[info exists ::starkit::topdir]} {
  set APPDATA(docdir) "[file dirname $::starkit::topdir]/doc"
} else {
  set APPDATA(docdir) "[file dirname [info script]]/doc"
}
# Check for "HP15Cdocdir" environment variable (intended for Linux packages)
if {[info exists ::env(HP15Cdocdir)] && [file isdirectory $::env(HP15Cdocdir)]} {
  set APPDATA(docdir) [file normalize $::env(HP15Cdocdir)]
}
if {$APPDATA(docdir) eq "."} {set APPDATA(docdir) [pwd]}

# ------------------------------------------------------------------------------
# Platform specific settings

switch $::tcl_platform(platform) {
  windows {
    set APPDATA(browserlist) \
      {start firefox chrome mozilla opera edge iexplore hh}
    switch -glob "$::tcl_platform(os) $::tcl_platform(osVersion)" {
      "Windows NT 5.*" -
      "Windows NT 6.*" -
      "Windows NT 7.*" -
      "Windows NT 10.*" -
      "Windows NT 11.*" {set appdata [file normalize $::env(appdata)]}
      default {
        tk_messageBox -type ok -icon error -default ok \
          -title $APPDATA(title) \
          -message [mc app.noplatform $::tcl_platform(os) \
             $::tcl_platform(osVersion)]
        exit
      }
    }
    set APPDATA(HOME) "$appdata/HP-15C"
    set HP15(fsid) ms2

    event add <<B3>> <ButtonPress-3>

# Icons are merged into the tclkit. Use ico file for source code version only
    if {![info exists ::starkit::topdir] && [file exists hp-15c.ico]} {
      wm iconbitmap . hp-15c.ico
    }

    font configure HP15C_Menu_Font -weight bold
  }
  unix {
    switch -glob "$::tcl_platform(os) $::tcl_platform(osVersion)" {
      "Darwin *" {
        set APPDATA(browserlist) {open firefox safari chrome opera}
        set APPDATA(control) "Command"
        set APPDATA(option) "Option"
        set APPDATA(PrefIcons) 0
        mcset en gen.ctrl "\u2318"
        event add <<B3>> <ButtonPress-2> <Control-ButtonPress-1>
        set HP15(fsid) dv2
      }
      default    {
        set APPDATA(browserlist) {firefox chrome mozilla opera konqueror}
        event add <<B3>> <ButtonPress-3>
        set HP15(fsid) dv2
      }
    }
    set APPDATA(HOME) "$::env(HOME)/.HP-15C"
  }
  default {
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) \
      -message [mc app.noplatform $::tcl_platform(os) $::tcl_platform(osVersion)]
    exit
  }
}

# Common settings actions
if {![file isdirectory $APPDATA(HOME)]} {
  catch {file mkdir $APPDATA(HOME)}
}
set HP15(prgmdir) $APPDATA(HOME)

# ------------------------------------------------------------------------------
# Load images.
set dnam "lib/images"
if {![file exists $dnam]} {
  set dnam "$APPDATA(basedir)/images"
}

foreach img {PrefIconSimulator.gif PrefIconSystem.gif PrefIconFiles.gif
  PrefIconDM15CC.gif PrefIconFonts.gif PrefIconHelp.gif PrevIconDev.gif
  dispframe.gif beveltop.gif HP-15C-logo-256.png HP-15C-logo-512.png} {
  unset -nocomplain fnam
  set fnam "$dnam/$img"
  if {[file exists $fnam]} {
    catch {set APPDATA([file rootname $img]) [image create photo -file $fnam]}
  }
}

# On macOS iconphoto was buggy before 8.6.8
# Windows does not scale down small icons properly, skip it
if {$::tcl_platform(platform) eq "unix" &&
    !($::tcl_platform(os) eq "Darwin" && \
      [package vcompare [info patchlevel] 8.6.8] > 0)} {
  if {[info exists APPDATA(HP-15C-logo-512)]} {
    wm iconphoto . -default $APPDATA(HP-15C-logo-512) $APPDATA(HP-15C-logo-256)
  }
}

# ------------------------------------------------------------------------------
# From now on we will use our own exit handler
rename ::exit ::exit_org

# ------------------------------------------------------------------------------
# Menu structures for win32, x11 and aqua

array set MENU {
  win32 { \
    {menubar .mbar} \
    {menu   {.mbar .file} gen.file menu_post} \
    {cmd    .file  menu.openprgm {gen.ctrl $::HP15(combkey) O} prgm_getfile} \
    {menu   {.mbar.file .recent} menu.recent hist_menu} \
    {sep    .file} \
    {cmd    .file  menu.saveprgm {gen.ctrl $::HP15(combkey) S} prgm_save} \
    {cmd    .file  menu.savehtml {gen.ctrl $::HP15(combkey) E} \
      {prgm_save "[mc app.exthtml]"}} \
    {cmd    .file  menu.prgmdocu {gen.ctrl $::HP15(combkey) D} ::prdoc::Edit} \
    {sep    .file} \
    {cmd    .file  menu.loadmem  {gen.ctrl $::HP15(combkey) L} mem_load} \
    {cmd    .file  menu.savemem  {gen.ctrl $::HP15(combkey) M} mem_save} \
    {cmd    .file  menu.resetmem {gen.ctrl $::HP15(combkey) R} mem_reset} \
    {sep    .file  "" "" "" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.read {gen.ctrl $::HP15(combkey) "\u2191"} \
      "DM15_do read" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.write {gen.ctrl $::HP15(combkey) "\u2193"} \
      "DM15_do write" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15.sysinfo {gen.ctrl $::HP15(combkey) I} \
      "DM15_sysinfo" {visible "::DM15(dm15cc)"}} \
    {sep    .file} \
    {cmd    .file  gen.exit {gen.alt $::HP15(combkey) F4} exit} \
    {menu   {.mbar .edit} gen.edit menu_post} \
    {cmd    .edit  gen.copy {gen.ctrl $::HP15(combkey) C} "clipboard_set 0"} \
    {cmd    .edit  gen.copyfmtd {gen.ctrl $::HP15(combkey) gen.shift \
      $::HP15(combkey) C} "clipboard_set 1"} \
    {cmd    .edit  gen.paste {gen.ctrl $::HP15(combkey) V} clipboard_get} \
    {sep    .edit} \
    {cmd    .edit  menu.clearall {gen.shift $::HP15(combkey) ESC} clearall} \
    {menu   {.mbar .view} gen.view menu_post} \
    {chkbtn .view pref.mnemonics F11 {} {options "-variable ::HP15(mnemonics)"}} \
    {chkbtn .view pref.prgmcoloured {gen.alt $::HP15(combkey) F11} "" \
      {options "-variable ::HP15(prgmcoloured)"}} \
    {sep    .view} \
    {chkbtn .view pref.stomenudesc {} "" \
      {options "-variable ::HP15(stomenudesc)"}} \
    {chkbtn .view pref.sortgsb {} "" \
      {options "-variable ::HP15(sortgsb)"}} \
    {sep    .view} \
    {chkbtn .view pref.seqindicator {} "" \
      {options "-variable ::HP15(seqindicator)"}} \
    {cmd    .view menu.flipseps Alt-. exchange_seps} \
    {menu   {.mbar .prefs} gen.prefs menu_post } \
    {chkbtn .prefs menu.ontop {gen.ctrl $::HP15(combkey) T} gui_top \
      {options "-variable ::HP15(wm_top)"}} \
    {chkbtn .prefs pref.savewinpos {} "" \
      {options "-variable ::HP15(savewinpos)"}} \
    {sep    .prefs} \
    {cmd    .prefs menu.prefs {gen.ctrl $::HP15(combkey) ,} preferences} \
    {menu   {.mbar .help}  gen.help menu_post} \
    {cmd    .help  menu.hp15chelp F1 "help simulator"} \
    {cmd    .help  menu.backside {} back_side} \
    {cmd    .help  menu.htmlhelp {gen.ctrl $::HP15(combkey) F1} "help prgm"} \
    {sep    .help} \
    {cmd    .help  menu.about {} about} \
  }
  x11 { \
    {menubar .mbar} \
    {menu   {.mbar .file} gen.file menu_post} \
    {cmd    .file  menu.openprgm {gen.ctrl $::HP15(combkey) O} prgm_getfile} \
    {menu   {.mbar.file .recent} menu.recent hist_menu} \
    {sep    .file} \
    {cmd    .file  menu.saveprgm {gen.ctrl $::HP15(combkey) S} prgm_save} \
    {cmd    .file  menu.savehtml {gen.ctrl $::HP15(combkey) E} \
      {prgm_save "[mc app.exthtml]"}} \
    {cmd    .file  menu.prgmdocu {gen.ctrl $::HP15(combkey) D} ::prdoc::Edit} \
    {sep    .file} \
    {cmd    .file  menu.loadmem  {gen.ctrl $::HP15(combkey) L} mem_load} \
    {cmd    .file  menu.savemem  {gen.ctrl $::HP15(combkey) M} mem_save} \
    {cmd    .file  menu.resetmem {gen.ctrl $::HP15(combkey) R} mem_reset} \
    {sep    .file  "" "" "" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.read {gen.ctrl $::HP15(combkey) "\u2191"} \
      "DM15_do read" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.write {gen.ctrl $::HP15(combkey) "\u2193"} \
      "DM15_do write" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15.sysinfo {gen.ctrl $::HP15(combkey) I} \
      "DM15_sysinfo" {visible "::DM15(dm15cc)"}} \
    {sep    .file} \
    {cmd    .file  gen.exit {gen.ctrl $::HP15(combkey) Q} exit} \
    {menu   {.mbar .edit} gen.edit menu_post} \
    {cmd    .edit  gen.copy {gen.ctrl $::HP15(combkey) C} "clipboard_set 0"} \
    {cmd    .edit  gen.copyfmtd {gen.ctrl $::HP15(combkey) gen.shift \
      $::HP15(combkey) C} "clipboard_set 1"} \
    {cmd    .edit  gen.paste {gen.ctrl $::HP15(combkey) V} clipboard_get} \
    {sep    .edit} \
    {cmd    .edit  menu.clearall {gen.shift $::HP15(combkey) ESC} clearall} \
    {sep    .edit} \
    {cmd    .edit menu.prefs {gen.ctrl $::HP15(combkey) ,} preferences} \
    {menu   {.mbar .view} gen.view menu_post} \
    {chkbtn .view pref.mnemonics F11 {} {options "-variable ::HP15(mnemonics)"}} \
    {chkbtn .view pref.prgmcoloured {gen.alt $::HP15(combkey) F11} "" \
      {options "-variable ::HP15(prgmcoloured)"}} \
    {sep    .view} \
    {chkbtn .view pref.stomenudesc {} "" \
      {options "-variable ::HP15(stomenudesc)"}} \
    {chkbtn .view pref.sortgsb {} "" \
      {options "-variable ::HP15(sortgsb)"}} \
    {sep    .view} \
    {chkbtn .view pref.seqindicator {} "" \
      {options "-variable ::HP15(seqindicator)"}} \
    {cmd    .view menu.flipseps Alt-. exchange_seps} \
    {sep    .view} \
    {chkbtn .view menu.ontop {gen.ctrl $::HP15(combkey) T} gui_top \
      {options "-variable ::HP15(wm_top)"}} \
    {chkbtn .view pref.savewinpos {} "" \
      {options "-variable ::HP15(savewinpos)"}} \
    {menu   {.mbar .help} gen.help menu_post} \
    {cmd    .help  menu.hp15chelp F1 "help simulator"} \
    {cmd    .help  menu.backside {} back_side} \
    {cmd    .help  menu.htmlhelp {gen.ctrl $::HP15(combkey) F1} "help prgm"} \
    {sep    .help} \
    {cmd    .help  menu.about {} about} \
  }
  aqua { \
    {menubar .mbar} \
    {menu   {.mbar .apple} "HP-15C" menu_post} \
    {cmd    .apple  menu.about {} about} \
    {sep    .apple} \
    {menu   {.mbar .file} gen.file menu_post} \
    {cmd    .file  menu.openprgm Command-O prgm_getfile} \
    {menu   {.mbar.file .recent} menu.recent hist_menu} \
    {sep    .file} \
    {cmd    .file  menu.saveprgm Command-S prgm_save} \
    {cmd    .file  menu.savehtml Command-E {prgm_save "[mc app.exthtml]"}} \
    {cmd    .file  menu.prgmdocu Command-D ::prdoc::Edit} \
    {sep    .file} \
    {cmd    .file  menu.loadmem Command-L mem_load} \
    {cmd    .file  menu.savemem Command-M mem_save} \
    {cmd    .file  menu.resetmem Command-R mem_reset} \
    {sep    .file  "" "" "" {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.read Command-Up "DM15_do read" \
      {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15cc.write Command-Down "DM15_do write" \
      {visible "::DM15(dm15cc)"}} \
    {cmd    .file  menu.dm15.sysinfo Command-I \
      "DM15_sysinfo" {visible "::DM15(dm15cc)"}} \
    {menu   {.mbar .edit} gen.edit menu_post} \
    {cmd    .edit  gen.copy Command-C "clipboard_set 0"} \
    {cmd    .edit  gen.copyfmtd Shift-Command-C "clipboard_set 1"} \
    {cmd    .edit  gen.paste Command-V clipboard_get} \
    {sep    .edit} \
    {cmd    .edit  menu.clearall Shift-Escape clearall} \
    {menu   {.mbar .view} gen.view menu_post} \
    {chkbtn .view  pref.mnemonics F11 {} {options "-variable ::HP15(mnemonics)"}} \
    {chkbtn .view  pref.prgmcoloured Command-F11 "" \
      {options "-variable ::HP15(prgmcoloured)"}} \
    {sep    .view} \
    {chkbtn .view pref.stomenudesc {} "" \
      {options "-variable ::HP15(stomenudesc)"}} \
    {chkbtn .view pref.sortgsb {} "" \
      {options "-variable ::HP15(sortgsb)"}} \
    {sep    .view} \
    {chkbtn .view pref.seqindicator {} "" \
      {options "-variable ::HP15(seqindicator)"}} \
    {cmd    .view  menu.flipseps Command-Option-. exchange_seps} \
    {sep    .view} \
    {chkbtn .view menu.ontop Command-T gui_top \
      {options "-variable ::HP15(wm_top)"}} \
    {chkbtn .view pref.savewinpos {} "" \
      {options "-variable ::HP15(savewinpos)"}} \
    {menu   {.mbar .info} gen.help menu_post} \
    {cmd    .info  menu.backside {} "back_side"} \
    {cmd    .info  menu.hp15chelp F1 "help simulator"} \
    {cmd    .info  menu.htmlhelp Command-F1 "help prgm"} \
  }
}

set ERRORS [list \
  "y \u00F7 0, LN 0, \u2026" \
  "LN A, SIN A, \u2026" \
  "\u2211 Error" \
  "R?, A\u1D62\u2C7C?" \
  "LBL?,GTO>MEM,PRGM>MEM" \
  "> 7 \[RTN\]" \
  "SF > 9, CF > 9, F? > 9" \
  "SOLVE(SOLVE), \u222Bxy (\u222Bxy)" \
  "SOLVE ?" \
  "\[ON\]\u2002/\u2002\[\u00D7\]" \
  "DIM > MEM" \
  "DIM A \u2260 DIM B" \
]

set MATFUNCS [list \
  "0 DIM" \
  "1\u2192R\u2080,1\u2192R\u2081" \
  "A\u1D3e \u2192 \u00C3" \
  "\u00C3 \u2192 A\u1D3e" \
  "A\u1D40" \
  "A\u1D40 B" \
  "B=B\u2212AC" \
  "MAX \u2211|a\u1D62\u2C7C|" \
  "(\u2211|a\u1D62\u2C7C|\u00B2)\u00B9\u2044\u2082" \
  "|A|"
]

# Test menu labels. Also used for mnemonics.
set TEST { "x \u2260 0" "x > 0" "x < 0" "x \u2265 0" "x \u2264 0" "x = y" \
  "x \u2260 y" "x > y" "x < y" "x \u2265 y" "x \u2264 y" "x = 0" }

# ------------------------------------------------------------------------------
# Initialize processor, stack and storage registers

array set STATUS_DEF {
  f 0
  g 0
  user 0
  BEGIN 0
  RAD {}
  rangle 180.0
  DMY 0
  PRGM 0
  integrate 0
  ixclear 0
  solve 0
  num 1
  liftlock 1
  dispmode FIX
  dispprec 4
  comma ,
  dot .
  error 0
  result M1
  seed 0
  null -1
}
array set status [array get STATUS_DEF]

# During execution two additional registers are added to the stack:
#   s: general scratchpad register that stores the last operand
#   u: used by helper functions in complex mode

array set stack {
  m 0.0
  s 0.0
  u 0.0
  x 0.0
  y 0.0
  z 0.0
  t 0.0
  LSTx 0.0
}

array set istack {
  m 0.0
  s 0.0
  u 0.0
  x 0.0
  y 0.0
  z 0.0
  t 0.0
  LSTx 0.0
}

# Storage
array set storage {}

# Matrices
array set MAT {
  M1 {}
  M2 {}
  M3 {}
  M4 {}
  M5 {}
  M1_LU {}
  M2_LU {}
  M3_LU {}
  M4_LU {}
  M5_LU {}
}

# Flags
array set FLAG { 0 0 1 0 2 0 3 0 4 0 5 0 6 0 7 0 8 0 9 0 }

array set prgstat_DEF {
  curline 0
  running 0
  interrupt 0
  rtnadr {}
}
array set prgstat [array get prgstat_DEF]

# Program Documentation settings
set PRGM {{}}

# ------------------------------------------------------------------------------
# Global program control variables

set curdisp 0
set flashid 0
set blinkpr 0
set keyseq ""
set pendingseq ""
set ShowX 1
set prgmtype ""
set blink_t 0
set blink_id 0

array set KBD {
  state 1
  wait 0
  release_trig 0
}

# ------------------------------------------------------------------------------
# List of HP-15C keys

# Key definitions
# Each key definition consists of 10 elements:
#   0: row 1: column : Row [1-4] and column [1-10] on the key pad.
#   2: rowspan       : Numbers of rows a key spans. Normally 1, 2 for ENTER.
#   3: key-code      : Normally row+column, but numeric keys return number.
#   4: f-label 5: label 6: g-label : The key's labels. Encoded in UNICODE.
#   7: f-binding 8: binding 9: g-binding : List of X11-keysyms bound to a key.
#
set HP15_KEYS_DEF {
  { 1  1 1 11 A \u221Ax\u0305 x\u00B2 {} {q} {} }
  { 1  2 1 12 B e\u02E3 LN {} {e} {} }
  { 1  3 1 13 C 10\u02E3 LOG {} {x} {} }
  { 1  4 1 14 D y\u02E3 % {} {y} {percent} }
  { 1  5 1 15 E 1/x \u0394% {} {backslash ssharp} {d} }
  { 1  6 1 16 MATRIX CHS ABS {} {z} {a bar brokenbar} }
  { 1  7 1  7 FIX 7 DEG {} {7 KP_7} {} }
  { 1  8 1  8 SCI 8 RAD {} {8 KP_8} {} }
  { 1  9 1  9 ENG 9 GRD {} {9 KP_9} {} }
  { 1 10 1 10 SOLVE \u00F7 x\u2264y {} {slash KP_Divide} {} }
  { 2  1 1 21 LBL SST BST {F8} {} {} }
  { 2  2 1 22 HYP GTO HYP\u207B\u00B9 {h} {o F2} {} }
  { 2  3 1 23 DIM SIN SIN\u207B\u00B9 {} {s} {} }
  { 2  4 1 24 (i) COS COS\u207B\u00B9 {} {c} {} }
  { 2  5 1 25 I TAN TAN\u207B\u00B9 {I j} {t} {} }
  { 2  6 1 26 RESULT EEX \u03C0 {} {E} {p} }
  { 2  7 1  4 \u03A7\u2194 4 SF {} {4 KP_4} {} }
  { 2  8 1  5 DSE 5 CF {} {5 KP_5} {} }
  { 2  9 1  6 ISG 6 F? {} {6 KP_6} {question} }
  { 2 10 1 20 \u2320X\n\u2321Y \u00D7 x=0 {} {asterisk KP_Multiply} {} }
  { 3  1 1 31 PSE R/S P/R {F6} {v F5} {F9} }
  { 3  2 1 32 \u2211 GSB RTN {} {b F3} {F4} }
  { 3  3 1 33 PRGM R\u2B07 R\u2B06 {} {Down} {Up} }
  { 3  4 1 34 REG x\u2194y RND {} {less greater} {} }
  { 3  5 1 35 PREFIX \u2B05 CLx {} {BackSpace} {Escape} }
  { 3  6 2 36 "RAN\u2009#" ENTER LST\u03A7 {numbersign} {Return KP_Enter} {l} }
  { 3  7 1  1 \u2192\u2009R 1 \u2192P {} {1 KP_1} {} }
  { 3  8 1  2 \u2192H.MS 2 \u2192H {M} {2 KP_2} {H} }
  { 3  9 1  3 \u2192\u2009RAD 3 \u2192DEG {R} {3 KP_3} {D} }
  { 3 10 1 30 Re\u2194Im \u2212 TEST {Tab} {minus KP_Subtract} {} }
  { 4  1 1 41 "" ON "" {} {} {} }
  { 4  2 1 42 "" f "" {} {} {} }
  { 4  3 1 43 "" g "" {} {} {} }
  { 4  4 1 44 FRAC STO INT {F} {m} {n} }
  { 4  5 1 45 USER RCL MEM {u} {r} {} }
  { 4  7 1  0 \u03A7\u2009! 0 x\u0305 {exclam} {0 KP_0} {} }
  { 4  8 1 48 \u0177,r . s {} {comma period KP_Decimal KP_Separator} {} }
  { 4  9 1 49 L.R. \u2211+ \u2211\u2212 {} {Insert} {Delete} }
  { 4 10 1 40 P\u2009y,x + Cy,x {} {plus KP_Add} {} }
}
set HP15_KEYS {}

# HP-15C Key sequence, corresponding functions and function attributes
#   Key sequence: A regular expression describing a set of key sequences
#     The complete RE must be stored in a variable to become chached!
#   Function name: The Tcl function.
#   Attributes (0|1):
#     LSTx: Operand is saved in the LSTx register.
#     End input: Function terminates input. Thus we have a number.
#     Programmable: Function is programmable.
array set HP15_KEY_FUNCS {
  0 {
    {{^([0-9])$} "func_digit " 0 0 1}
  }
  1 {
    {{^10$} "func_div" 1 1 1}
    {{^11$} "func_sqrt" 1 1 1}
    {{^12$} "func_exp" 1 1 1}
    {{^13$} "func_10powx" 1 1 1}
    {{^14$} "func_ypowx" 1 1 1}
    {{^15$} "func_inv" 1 1 1}
    {{^16$} "func_chs" 0 0 1}
  }
  2 {
    {{^20$} "func_mult" 1 1 1}
    {{^22_([0-9])$} "func_gto " 0 1 1}
    {{^22_1([1-5])$} "func_gto -" 0 1 1}
    {{^22_25$} "func_gto I" 0 1 1}
    {{^22_48_([0-9])$} "func_gto 1" 0 1 1}
    {{^23$} "func_sin" 1 1 1}
    {{^24$} "func_cos" 1 1 1}
    {{^25$} "func_tan" 1 1 1}
    {{^26$} "func_EEX" 0 0 1}
    {{^21$} "func_sst" 0 0 0}
    {{^22_16_([0-9])$} "func_gto_chs " 0 0 0}
  }
  3 {
    {{^30$} "func_minus" 1 1 1}
    {{^31$} "func_rs" 0 0 1}
    {{^32_([0-9])$} "func_gsb " 0 1 1}
    {{^32_1([1-5])$} "func_gsb -" 0 1 1}
    {{^32_25$} "func_gsb I" 0 1 1}
    {{^32_48_([0-9])$} "func_gsb 1" 0 1 1}
    {{^33$} "func_roll 1" 0 1 1}
    {{^34$} "func_xy" 0 1 1}
    {{^35$} "func_bs" 0 0 0}
    {{^36$} "func_enter" 0 1 1}
  }
  4 {
    {{^40$} "func_plus" 1 1 1}
    {{^41$} "func_on" 0 0 0}
    {{^48$} "func_point" 0 0 1}
    {{^49$} "func_sum_plus" 1 1 1}
  }
  42_0 {
    {{^42_0$} "func_faculty" 1 1 1}
    {{^42_1$} "func_rectangular" 1 1 1}
    {{^42_2$} "func_hms" 1 1 1}
    {{^42_3$} "func_rad" 1 1 1}
    {{^42_4_([0-9])$} "func_xexchg " 0 1 1}
    {{^42_4_1([1-5])$} "func_xexchg M" 0 1 1}
    {{^42_4_24$} "func_xexchg (i)" 0 1 1}
    {{^42_4_25$} "func_xexchg I" 0 1 1}
    {{^42_4_48_([0-9])$} "func_xexchg 1" 0 1 1}
    {{^42_5_([0-9])$} "func_dse " 0 1 1}
    {{^42_5_1([1-5])$} "func_dse M" 0 1 1}
    {{^42_5_24$} "func_dse (i)" 0 1 1}
    {{^42_5_25$} "func_dse I" 0 1 1}
    {{^42_5_48_([0-9])$} "func_dse 1" 0 1 1}
    {{^42_6_([0-9])$} "func_isg " 0 1 1}
    {{^42_6_1([1-5])$} "func_isg M" 0 1 1}
    {{^42_6_24$} "func_isg (i)" 0 1 1}
    {{^42_6_25$} "func_isg I" 0 1 1}
    {{^42_6_48_([0-9])$} "func_isg 1" 0 1 1}
    {{^42_7_([0-9])$} "func_dsp_mode FIX " 0 1 1}
    {{^42_7_25$} "func_dsp_mode FIX I" 0 1 1}
    {{^42_8_([0-9])$} "func_dsp_mode SCI " 0 1 1}
    {{^42_8_25$} "func_dsp_mode SCI I" 0 1 1}
    {{^42_9_([0-9])$} "func_dsp_mode ENG " 0 1 1}
    {{^42_9_25$} "func_dsp_mode ENG I" 0 1 1}
  }
  42_1 {
    {{^42_1([1-5])$} "dispatch_key 32_1" 0 0 0}
    {{^42_10_([0-9])$} "func_solve " 0 1 1}
    {{^42_10_1([1-5])$} "func_solve -" 0 1 1}
    {{^42_10_48_([0-9])$} "func_solve 1" 0 1 1}
    {{^42_16_([0-9])$} "func_matrix " 1 1 1}
  }
  42_2 {
    {{^42_20_([0-9])$} "func_integrate " 0 0 1}
    {{^42_20_1([1-5])$} "func_integrate -" 0 0 1}
    {{^42_20_48_([0-9])$} "func_integrate 1" 0 0 1}
    {{^42_21_([0-9])$} "func_label " 0 1 1}
    {{^42_21_1([1-5])$} "func_label " 0 1 1}
    {{^42_21_48_([0-9])$} "func_label 1" 0 1 1}
    {{^42_22_23$} "func_hyp sin" 1 1 1}
    {{^42_22_24$} "func_hyp cos" 1 1 1}
    {{^42_22_25$} "func_hyp tan" 1 1 1}
    {{^42_23_1([1-5])$} "func_dim_matrix " 0 1 1}
    {{^42_23_25$} "func_dim_matrix I" 0 1 1}
    {{^42_23_24$} "func_dim_mem" 0 1 1}
    {{^42_24$} "func_i" 0 1 0}
    {{^42_25$} "func_I" 0 1 1}
    {{^42_26_1([1-5])$} "func_result " 0 1 1}
  }
  42_3 {
    {{^42_30$} "func_re_im" 0 1 1}
    {{^42_31$} "func_pse" 0 1 1}
    {{^42_32$} "func_clearsumregs" 0 1 1}
    {{^42_33$} "func_clearprgm" 0 1 0}
    {{^42_34$} "func_clearreg" 0 1 1}
    {{^42_35$} "func_prefix" 0 1 0}
    {{^42_36$} "func_random" 0 1 1}
  }
  42_4 {
    {{^42_40$} "func_Pyx" 1 1 1}
    {{^42_44$} "func_frac" 1 1 1}
    {{^42_45$} "set_status USER" 0 1 0}
    {{^42_48$} "func_linexpolation" 1 1 1}
    {{^42_49$} "func_linreg" 0 1 1}
  }
  43_0 {
    {{^43_0$} "func_avg" 0 1 1}
    {{^43_1$} "func_polar" 1 1 1}
    {{^43_2$} "func_h" 1 1 1}
    {{^43_3$} "func_deg" 1 1 1}
    {{^43_4_([0-9])$} "func_sf " 0 1 1}
    {{^43_4_25$} "func_sf I" 0 1 1}
    {{^43_5_([0-9])$} "func_cf " 0 1 1}
    {{^43_5_25$} "func_cf I" 0 1 1}
    {{^43_6_([0-9])$} "func_Finq " 0 1 1}
    {{^43_6_25$} "func_Finq I" 0 1 1}
    {{^43_7$} "set_status DEG" 0 1 1}
    {{^43_8$} "set_status RAD" 0 1 1}
    {{^43_9$} "set_status GRAD" 0 1 1}
  }
  43_1 {
    {{^43_10$} "func_test 10" 0 1 1}
    {{^43_11$} "func_xpow2" 1 1 1}
    {{^43_12$} "func_ln" 1 1 1}
    {{^43_13$} "func_log10" 1 1 1}
    {{^43_14$} "func_percent" 1 1 1}
    {{^43_15$} "func_dpercent" 1 1 1}
    {{^43_16$} "func_abs" 1 1 1}
  }
  43_2 {
    {{^43_20$} "func_test 11" 0 1 1}
    {{^43_21$} "func_bst" 0 1 0}
    {{^43_22_23$} "func_ahyp sin" 1 1 1}
    {{^43_22_24$} "func_ahyp cos" 1 1 1}
    {{^43_22_25$} "func_ahyp tan" 1 1 1}
    {{^43_23$} "func_atrign sin" 1 1 1}
    {{^43_24$} "func_atrign cos" 1 1 1}
    {{^43_25$} "func_atrign tan" 1 1 1}
    {{^43_26$} "func_pi" 0 1 1}
  }
  43_3 {
    {{^43_30_([0-9])$} "func_test " 0 1 1}
    {{^43_31$} "func_pr" 0 0 0}
    {{^43_32$} "func_rtn" 0 1 1}
    {{^43_33$} "func_roll 3" 0 1 1}
    {{^43_34$} "func_rnd" 1 1 1}
    {{^43_35$} "func_clx" 0 1 1}
    {{^43_36$} "func_lastx" 0 1 1}
  }
  43_4 {
    {{^43_40$} "func_Cyx" 1 1 1}
    {{^43_44$} "func_int" 1 1 1}
    {{^43_45$} "func_mem" 0 1 0}
    {{^43_48$} "func_stddev" 0 1 1}
    {{^43_49$} "func_sum_minus" 1 1 1}
  }
  44_0 {
    {{^44_([0-9])$} "func_sto " 0 1 1}
  }
  44_1 {
    {{^44_1([1-5])$} "func_sto_matrix regs {} " 0 1 1}
    {{^44_1([1-5])_u$} "func_sto_matrix regs user " 0 1 1}
    {{^44_10_([0-9])$} "func_sto_oper / " 0 1 1}
    {{^44_10_1([1-5])$} "func_sto_oper / M" 0 1 1}
    {{^44_10_24$} "func_sto_oper / (i)" 0 1 1}
    {{^44_10_25$} "func_sto_oper / I" 0 1 1}
    {{^44_10_48_([0-9])$} "func_sto_oper / 1" 0 1 1}
    {{^44_16_1([1-5])$} "func_set_matrix " 0 1 1}
  }
  44_2 {
    {{^44_20_([0-9])$} "func_sto_oper * " 0 1 1}
    {{^44_20_1([1-5])$} "func_sto_oper * M" 0 1 1}
    {{^44_20_24$} "func_sto_oper * (i)" 0 1 1}
    {{^44_20_25$} "func_sto_oper * I" 0 1 1}
    {{^44_20_48_([0-9])$} "func_sto_oper * 1" 0 1 1}
    {{^44_24$} "func_sto_i {}" 0 1 1}
    {{^44_24_u$} "func_sto_i user" 0 1 1}
    {{^44_25$} "func_sto I" 0 1 1}
    {{^44_26$} "func_sto_result " 0 1 1}
  }
  44_3 {
    {{^44_30_([0-9])$} "func_sto_oper - " 0 1 1}
    {{^44_30_1([1-5])$} "func_sto_oper - M" 0 1 1}
    {{^44_30_24$} "func_sto_oper - (i)" 0 1 1}
    {{^44_30_25$} "func_sto_oper - I" 0 1 1}
    {{^44_30_48_([0-9])$} "func_sto_oper - 1" 0 1 1}
    {{^44_*36$} "func_storandom" 0 1 1}
  }
  44_4 {
    {{^44_40_([0-9])$} "func_sto_oper + " 0 1 1}
    {{^44_40_1([1-5])$} "func_sto_oper + M" 0 1 1}
    {{^44_40_24$} "func_sto_oper + (i)" 0 1 1}
    {{^44_40_25$} "func_sto_oper + I" 0 1 1}
    {{^44_40_48_([0-9])$} "func_sto_oper + 1" 0 1 1}
    {{^44_43_1([1-5])$} "func_sto_matrix stack {} " 0 1 1}
    {{^44_43_24$} "func_sto_matrix stack {} (i)" 0 1 1}
    {{^44_48_([0-9])$} "func_sto 1" 0 1 1}
  }
  45_0 {
    {{^45_([0-9])$} "func_rcl " 0 1 1}
  }
  45_1 {
    {{^45_1([1-5])$} "func_rcl_matrix regs {} " 0 1 1}
    {{^45_1([1-5])_u$} "func_rcl_matrix regs user " 0 1 1}
    {{^45_10_([0-9])$} "func_rcl_oper / " 0 1 1}
    {{^45_10_1([1-5])$} "func_rcl_oper / M" 0 1 1}
    {{^45_10_24$} "func_rcl_oper / (i)" 0 1 1}
    {{^45_10_25$} "func_rcl_oper / I" 0 1 1}
    {{^45_10_48_([0-9])$} "func_rcl_oper / 1" 0 1 1}
    {{^45_16_1([1-5])$} "func_rcl_descriptor " 0 1 1}
  }
  45_2 {
    {{^45_20_([0-9])$} "func_rcl_oper * " 0 1 1}
    {{^45_20_1([1-5])$} "func_rcl_oper * M" 0 1 1}
    {{^45_20_24$} "func_rcl_oper * (i)" 0 1 1}
    {{^45_20_25$} "func_rcl_oper * I" 0 1 1}
    {{^45_20_48_([0-9])$} "func_rcl_oper * 1" 0 1 1}
    {{^45_23_1([1-5])$} "func_rcl_dim_matrix " 0 1 1}
    {{^45_23_24$} "func_rcl_dim_i" 0 1 1}
    {{^45_23_25$} "func_rcl_dim_matrix I" 0 1 1}
    {{^45_24$} "func_rcl_i {}" 0 1 1}
    {{^45_24_u$} "func_rcl_i user" 0 1 1}
    {{^45_25$} "func_rcl I" 0 1 1}
    {{^45_26$} "func_rcl_result " 0 1 1}
  }
  45_3 {
    {{^45_30_([0-9])$} "func_rcl_oper - " 0 1 1}
    {{^45_30_1([1-5])$} "func_rcl_oper - M" 0 1 1}
    {{^45_30_24$} "func_rcl_oper - (i)" 0 1 1}
    {{^45_30_25$} "func_rcl_oper - I" 0 1 1}
    {{^45_30_48_([0-9])$} "func_rcl_oper - 1" 0 1 1}
    {{^45_36$} "func_rclrandom" 0 1 1}
  }
  45_4 {
    {{^45_40_([0-9])$} "func_rcl_oper + " 0 1 1}
    {{^45_40_1([1-5])$} "func_rcl_oper + M" 0 1 1}
    {{^45_40_24$} "func_rcl_oper + (i)" 0 1 1}
    {{^45_40_25$} "func_rcl_oper + I" 0 1 1}
    {{^45_40_48_([0-9])$} "func_rcl_oper + 1" 0 1 1}
    {{^45_43_1([1-5])$} "func_rcl_matrix stack {} " 0 1 1}
    {{^45_43_24$} "func_rcl_matrix stack {} (i)" 0 1 1}
    {{^45_48_([0-9])$} "func_rcl 1" 0 1 1}
    {{^45_49$} "func_rclsum" 0 1 1}
  }
}

# ------------------------ End of variable definitions -------------------------

# ------------------------------------------------------------------------------
proc commify { num {sign ,} } {

  if {$sign eq "."} {regsub {[.]} $num "," num}
  set trg "\\1$sign\\2\\3"
  while {[regsub {^([-+ ]?[0-9]+)([0-9]{3})([- ][0-9][0-9])?} \
    $num $trg num]} {}

  return $num

}

# ------------------------------------------------------------------------------
proc format_mark { mm } {

  global HP15 status

  if {[string is integer $mm]} {
    if {$mm < 0} {
      set rc [format "\u2002%1c" [expr 64-$mm]]
    } elseif {$mm < 10} {
      set rc [format "\u2002%1d" $mm]
    } elseif {$mm < 20 && $HP15(dotmarks)} {
      set rc [format "$status(comma)%1d" [expr $mm-10]]
    } else {
      set rc [format "%2d" $mm]
    }
  } else {
    set rc [format "%s" $mm]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc format_exponent { expo } {

  if {$expo ne ""} {
    regsub {^([-+ ]?)0*([1-9][0-9]?)} $expo {\1\2} expo
    if {[string first "-" $expo] >= 0} {
      set pfix "-"
    } else {
      set pfix " "
    }
    set expo [format "$pfix%02d" [expr abs($expo)]]
  }
  return $expo

}

# ------------------------------------------------------------------------------
proc format_number { var } {

  global status

  set prec $status(dispprec)
  set eex 1

# calculate mantissa and exponent parameters
  set log [expr $var != 0 ? int(floor(log10(abs($var)))) : 0]
  if {$status(dispmode) eq "FIX"} {
    if {($log >= -$prec && $log <= 9) ||
       ($log < 0 && [troundn [expr abs($var)] $prec] != 0.0)} {
      set eex 0
      if {$log+$prec > 9} {set prec [expr 9-$log]}
    }
  }

# format mantissa
  if {$var >= 0} {
    append fmt "% ." $prec "f"
  } else {
    append fmt "-%." $prec "f"
  }
  if {$var >= $::s56b::MAXVAL} {
    set mantissa " [string range $::s56b::MAXVAL 0 7]"
  } elseif {$var <= -$::s56b::MAXVAL} {
    set mantissa "-[string range $::s56b::MAXVAL 0 7]"
  } elseif {$eex == 1} {
    set mantissa [troundn [expr {abs($var)/pow(10, $log)}] $prec]

    if {$status(dispmode) eq "ENG"} {
      set engexp [expr {int($log/3)*3}]
      set mantissa [expr {$mantissa*10**($log-$engexp)}]
      set log $engexp
    }

    set len [expr {min($prec, 6)+2}]
    set len [expr {max([string first "." $mantissa], $len)}]
    set mantissa [string range [format $fmt $mantissa] 0 $len]
  } else {
    set mantissa [format $fmt [troundn [expr {abs($var)}] $prec]]
  }
  if {[string first "." $mantissa] <= 0} {set mantissa "$mantissa."}

# WA: Some systems do no distinguish between "-0.0" and "0.0"
   if {$var == 0.0 && [string index $mantissa 0] eq "-"} {
     set mantissa " [string range $mantissa 1 end]"
   }

# append exponent
  if {$eex == 1} {
    append mantissa [string repeat " " [expr 9-[string length $mantissa]]] \
      [format_exponent $log]
  }

  return [commify $mantissa $status(dot)]

}

# ------------------------------------------------------------------------------
proc format_descriptor { md } {

  global MAT

	if {[string index $md 0] eq "M"} {
    set mn [matrix_name $md]
    if {[isLU $md]} {
      append mn "--"
    }
    return [format "%-4s%3s%3s" $mn \
      [::matrix::Rows $MAT($md)] [::matrix::Cols $MAT($md)]]
  }

}

# ------------------------------------------------------------------------------
proc format_input { var } {

  global status

  regsub {(e[+-]$)} $var {\10} var
  regexp {^([-+ ]?[.0-9]+)e?([+-][0-9]+)?} $var all mantissa expo

  if {[string index $mantissa 0] ne "-"} {set mantissa " $mantissa"}
  set expo [format_exponent $expo]
  set filler [string repeat " " \
    [expr 11-[string length [string map {. ""} "$mantissa$expo"]]]]
  while {[string length $expo] > 0 && [count_digits $mantissa] > 7} {
    set mantissa [string range $mantissa 0 end-1]
  }

  return [commify "$mantissa$filler$expo" $status(dot)]

}

# ------------------------------------------------------------------------------
proc format_keyseq { seq wid } {

  global status

  set kl [split [regsub {_u} $seq {}] "_"]
  lassign $kl k0 k1 k2 k3
  switch [llength $kl] {
    1 -
    2 {
      set st [join $kl]
    }
    3 {
      if {$k1 == 48} {
        set st [format "  %2d $status(comma)%1d" $k0 $k2]
      } else {
        set st [format "%2d$status(dot)%2d$status(dot)%2d" $k0 $k1 $k2]
      }
    }
    4 {
      set st [format "%2d$status(dot)%2d$status(dot) %2s" $k0 $k1 "$status(comma)$k3"]
    }
    default {
      set st ""
    }
  }
  return [format "%$wid\s" $st]

}

# ------------------------------------------------------------------------------
proc lookup_label_ind { seq key } {

  switch $seq {
    "44" -
    "45" {
      set ind [expr [lsearch {11 12 13 14 15 16 23 24 25 26 36} $key] == -1 ? 5 : 4]
    }
    "42 23" -
    "42 26" {
      set ind [expr [lsearch {11 12 13 14 15 24 25 36} $key] == -1 ? 5 : 4]
    }
    "44 10" -
    "44 16" -
    "44 20" -
    "44 30" -
    "44 40" -
    "44 43" -
    "45 10" -
    "45 16" -
    "45 20" -
    "45 30" -
    "45 40" -
    "45 43" {
      set ind [expr [lsearch {11 12 13 14 15 23 24 25 36} $key] == -1 ? 5 : 4]
    }
    "45 23" {
      set ind 4
    }
    "22" -
    "32" -
    "42 10" -
    "42 20" -
    "42 21" {
      set ind [expr [lsearch {11 12 13 14 15 25} $key] == -1 ? 5 : 4]
    }
    "42 4" -
    "42 5" -
    "42 6" -
    "42 7" -
    "42 8" -
    "42 9" {
      set ind [expr [lsearch {11 12 13 14 15 24 25} $key] == -1 ? 5 : 4]
    }
    "42" {
      set ind 4
    }
    "43" {
      set ind 6
    }
    "43 4" -
    "43 5" -
    "43 6" {
      set ind [expr $key == 25 ? 4 : 5]
    }
    default {
      set ind 5
    }
  }

  return $ind

}

# ------------------------------------------------------------------------------
proc lookup_keyname { seq key } {

  global HP15_KEYS TEST

  set kname ""
  if {$key eq "u"} {
    set kname "USER"
  } elseif {$seq == "43 30"} {
    set kname [string map {" " ""} [lindex $TEST $key]]
  } elseif {$seq == "42" && $key == "20"} {
    set kname "\u222Bxy"
  } else {
    foreach kk $HP15_KEYS {
      if {[lindex $kk 3] == $key} {
        set kname [lindex $kk [lookup_label_ind $seq $key]]
        break
      }
    }
  }

  return $kname

}

# ------------------------------------------------------------------------------
proc format_mnemonic { step {wid 0} } {

  set rc {}
  set seq ""
  foreach key [split [regsub {_u} $step {}] "_"] {
    lappend rc [lookup_keyname $seq $key]
    set seq [string trim "$seq $key"]
  }
  return [format "%$wid\s" [string map {". " "."} [join $rc]]]

}

# ------------------------------------------------------------------------------
proc chk_range { n1 n2 op } {

  global FLAG
  upvar $n1 arr

  if {[isDescriptor $arr($n2)]} { return }

  if {[::s56b::Limit arr($n2)]} {
    set FLAG(9) 1
  }

}

# ------------------------------------------------------------------------------
# Trace routine only for X-reg. Does not check parameters!
proc chk_xreg { n1 n2 op } {

  global status prgstat FLAG stack

  if {[isDescriptor $stack(x)]} { return }

  if {[::s56b::Limit stack(x)]} {
    set FLAG(9) 1
  }
  if {!$prgstat(running) && !$status(integrate) && !$status(solve)} {
    show_x
  }

}

# ------------------------------------------------------------------------------
proc error_handler { errinfo } {

  global APPDATA status prgstat FLAG stack istack curdisp errorInfo

  set errnum -1
  set status(num) 1

  if {[lindex $errinfo 0] eq "ARITH"} {
    switch [lindex $errinfo 1] {
      OVERFLOW {
        set stack(x) $::s56b::MAXVAL
        set FLAG(9) 1
      }
      IOVERFLOW {
        set istack(x) $::s56b::MAXVAL
        set FLAG(9) 1
      }
      NOVERFLOW {
        set stack(x) -$::s56b::MAXVAL
        set FLAG(9) 1
      }
      INOVERFLOW {
        set istack(x) -$::s56b::MAXVAL
        set FLAG(9) 1
      }
      UNDERFLOW {
        set stack(x) 0.0
      }
      INVALID -
      default {
        set errnum 0
      }
    }
    if {[lindex $errinfo 1] in {OVERFLOW IOVERFLOW NOVERFLOW INOVERFLOW}} {
      chk_range istack x write
    }
    show_x
  } else {
    switch [lindex $errinfo 0] {
      MATRIX {
        set errnum 1
      }
      SUM {
        set errnum 2
      }
      INDEX {
        set errnum 3
      }
      ADDRESS {
        set errnum 4
      }
      RTN {
        set errnum 5
      }
      FLAG {
        set errnum 6
      }
      RECURSION {
        set errnum 7
      }
      SOLVE {
        set FLAG(9) 0
        set errnum 8
      }
      DIM {
        set errnum 10
      }
      DIMMAT {
        set errnum 11
      }
      INTERRUPT {
        set prgstat(running) 0
        set prgstat(interrupt) 0
        show_x
      }
      FILEIO {
        switch [lindex $errinfo 1] {
          ECREATE {
            set errmsg [mc err.ecreate]
          }
          ENOENT {
            set errmsg [mc err.enoent]
          }
          EOPEN {
            set errmsg [mc err.eopen]
          }
          NONE -
          EFMT {
            set errmsg "[mc err.efmt] [string range [lindex $errinfo 3] 0 511]"
          }
          INVCMD {
            set errmsg "[mc gen.file]: '[file tail [lindex $errinfo 4]]'\n[mc err.invcmd] [lindex $errinfo 3]"
          }
          CLPBRD {
            set errmsg "[mc gen.clipboard]: [mc err.invcmd] [lindex $errinfo 3]"
          }
          default {
            if {[lindex $errinfo 1] eq ""} {
              set errmsg "[mc err.file] $errorInfo"
            } else {
              set errmsg "[mc err.file]: \"[lindex $errinfo 1]\""
            }
          }
        }
        set errnum 98
        tk_messageBox -type ok -icon error -default ok \
          -title $APPDATA(title) -message "$errmsg:\n[lindex $errinfo 2]"
      }
      default {
        set errnum 99
        tk_messageBox -type ok -icon error -default ok \
          -title $APPDATA(title) -message "[mc app.internalerror]\n$errorInfo"
          set stack(x) 0.0
      }
    }
  }

  if {$errnum >= 0} {
    set status(error) 1
    set prgstat(running) 0
    set curdisp [format "  ERROR %2d" $errnum]
  }

}

# ------------------------------------------------------------------------------
proc show_x {} {

  global status stack MAT curdisp

  if {[isDescriptor $stack(x)]} {
    set curdisp " [format_descriptor $stack(x)]"
  } elseif {$status(num)} {
    set curdisp [format_number $stack(x)]
  } else {
    set curdisp [format_input $stack(x)]
  }
  set_status NIL

}

# ------------------------------------------------------------------------------
# Only called due to a trace! Do not call directly, use show_x instead
proc disp_update { n1 n2 op } {

  global HP15 curdisp

  if {$HP15(usetkpath)} {
    .gui.c itemconfigure On -fill ""
    .gui.c dtag On

    set pos -1
    foreach cc [split $curdisp {}] {
      if { !($cc in {"." ","}) } {
        incr pos
      }
      ::hplcd::Set .gui.c d$pos $cc
    }
    .gui.c itemconfigure On -fill #303030
  } else {
    .gui.c itemconfigure digit -text ""

    set pos -1
    foreach cc [split $curdisp {}] {
      switch -- $cc {
        "," {
          .gui.c itemconfigure p$pos -text ";"
        }
        "." {
          .gui.c itemconfigure p$pos -text "."
        }
        default {
          .gui.c itemconfigure d[incr pos] -text $cc
        }
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc disp_flash { args } {

  global LAYOUT HP15 FLAG prgstat flashid

  if {$FLAG(9)} {
    if {$flashid == 0 || [lindex $args 0] == $flashid} {
      incr flashid
      if {!$prgstat(running)} {
        if {[.gui.c itemcget d1 -fill] eq "black"} {
          .gui.c itemconfigure On -fill $LAYOUT(display)
        } else {
          .gui.c itemconfigure On -fill black
        }
      }
      after $HP15(flash) "disp_flash $flashid"
    }
  } else {
    set flashid 0
    .gui.c itemconfigure On -fill black
  }

}

# ------------------------------------------------------------------------------
proc disp_refresh {} {

  global status

  if {$status(PRGM)} {
    show_curline
  } else {
    show_x
  }

}

# ------------------------------------------------------------------------------
proc disp_null {} {

	global curdisp

	set curdisp { NVII}
	update idletasks

}

# ------------------------------------------------------------------------------
proc disp_scroll { inc } {

  global status

  if {$status(PRGM)} {
    if {$inc >= 0} {
      dispatch_key 21
    } else {
      dispatch_key 43_21
    }
  } else {
    if {$inc >= 0} {
      dispatch_key 43_33
    } else {
      dispatch_key 33
    }
  }

}

# ------------------------------------------------------------------------------
# Matrix helper functions
# ------------------------------------------------------------------------------
proc chk_matmem { mo mn } {

  global HP15 MAT

  set old [expr [::matrix::Rows $MAT($mo)]*[::matrix::Cols $MAT($mo)]]
  if {[isDescriptor $mn]} {
    incr new [expr [::matrix::Rows $MAT($mn)]*[::matrix::Cols $MAT($mn)]]
  } else {
    incr new $mn
  }
  if {$HP15(poolregsfree)+$old-$new < 0} { error "" "" {DIM} }

}

# ------------------------------------------------------------------------------
proc SETMAT { md mat {pivot {}} } {

  global MAT

  set MAT($md) $mat
  set MAT($md\_LU) $pivot

}

# ------------------------------------------------------------------------------
proc matrix_name { md } {

  return [lindex {0 A B C D E} [string index $md 1]]

}

# ------------------------------------------------------------------------------
proc matrix_init { } {

  global MAT

  foreach md [array names MAT {M?}] {
    SETMAT $md {}
  }
  mem_recalc

}

# ------------------------------------------------------------------------------
proc matrix_mem {} {

  global MAT

  set rc 0
  foreach md [array names MAT {M?}] {
    incr rc [expr [::matrix::Rows $MAT($md)]*[::matrix::Cols $MAT($md)]]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc matrix_iterate { md } {

  global storage MAT

  if {[isDescriptor $storage(0)] || [isDescriptor $storage(1)]} {
    error "" "" {MATRIX}
  }

  set rows [::matrix::Rows $MAT($md)]
  set cols [::matrix::Cols $MAT($md)]

  set storage(1) [expr $storage(1)+1.0]
  if {$storage(1) > $cols} {
    set storage(1) 1
    set storage(0) [expr $storage(0)+1.0]
    if {$storage(0) > $rows} {
      set storage(0) 1
    }
  }

}

# ------------------------------------------------------------------------------
proc matrix_getRowCol { md mode } {

  global stack storage MAT

  set rows [::matrix::Rows $MAT($md)]
  set cols [::matrix::Cols $MAT($md)]

# Read row/col from storage regs or stack
  if {$mode eq "regs"} {
    if {[isDescriptor $storage(0)] || [isDescriptor $storage(1)]} {
      error "" "" {MATRIX}
    }

    set row [expr int(abs($storage(0)))-1]
    set col [expr int(abs($storage(1)))-1]
  } else {
    if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
      error "" "" {MATRIX}
    }

    set row [expr int(abs($stack(y)))-1]
    set col [expr int(abs($stack(x)))-1]
  }

  if {$row < 0 || $row >= $rows || $col < 0 || $col >= $cols} {
    error "" "" {INDEX}
  }

  return [list $row $col]

}

# ------------------------------------------------------------------------------
proc matrix_copy { md fmt } {

  global HP15 status MAT

  array set separr {
    semicolon ";"
    comma ","
    tab "\t"
  }
  set sep $separr($HP15(matseparator))

  set rc ""
  foreach row $MAT($md) {
    foreach elm $row {
      if {$fmt} {
        set elm [regsub { +} [string trim [format_number $elm]] "e"]
      } elseif {!$HP15(clpbrdc)} {
        set elm [string map ". $status(comma)" $elm]
      }
      append rc "$elm$sep "
    }
    append rc "\n"
  }

  return $rc

}

# ------------------------------------------------------------------------------
# Skips next step during program execution at end of matrix iteration
proc matrix_cond_step { mat } {

  global prgstat storage

  if {$prgstat(running) &&
      [::matrix::Rows $mat] == $storage(0) &&
      [::matrix::Cols $mat] == $storage(1)} {
    prgm_incr 2
  }

}

# ------------------------------------------------------------------------------
proc mem_save {} {

  global APPDATA HP15 DM15 stack istack storage MAT prgstat PRGM FLAG

# Keep global status but set status to be saved as for shut-off!
  array set status [array get ::status]
  set status(error) 0
  set status(f) 0
  set status(g) 0
  set status(num) 1
  set status(solve) 0
  set status(integrate) 0
  set status(PRGM) 0
  set prgstat(interrupt) 0
  set prgstat(running) 0
  set prgstat(rtnadr) {}
  set FLAG(9) 0

# Remove leading zeros in x-register.
  check_attributes NIL

# Save window position?
  if {$HP15(savewinpos)} {
    set HP15(winpos) "+[winfo x .]+[winfo y .]"
  } else {
    set HP15(winpos) ""
  }

  ::prdoc::Purge $PRGM

  set sepline "# [string repeat - 78]"
  set fid [open "$APPDATA(HOME)/$APPDATA(memfile)" {RDWR CREAT TRUNC}]
  chan configure $fid -encoding unicode
  puts -nonewline $fid "\uFEFF"

  puts $fid $sepline
  puts $fid "# $APPDATA(model) Memory File"
  puts $fid "# The Simulator is $APPDATA(copyright)"
  puts $fid "# Version $APPDATA(version)"
  puts $fid "# Memory saved on [clock format [clock seconds] \
    -format "%d.%m.%Y %T"]"
  puts $fid $sepline
  puts $fid ""

  foreach aa {HP15 DM15 status stack istack storage MAT FLAG prgstat \
    ::prdoc::CONF ::prdoc::STATUS} {
    puts $fid $sepline
    puts $fid "# $aa"
    puts $fid "array set $aa {"
    foreach ii [lsort -dictionary [array names $aa]] {
      puts $fid "  $ii {[set ${aa}($ii)]}"
    }
    puts $fid "}\n"
  }

  puts $fid $sepline
  puts $fid "# Program documentation"
  puts $fid "array set ::prdoc::DESC {"
  foreach ii [lsort -dictionary [array names ::prdoc::DESC]] {
    set tmp($ii) $::prdoc::DESC($ii)
    puts $fid "  [array get tmp]"
    unset tmp
  }
   puts $fid "}\n"

  puts $fid $sepline
  puts $fid "# Program"
  puts $fid "set PRGM {"
  foreach ii $PRGM {
    puts $fid "  {$ii}"
  }
  puts $fid "}"
  puts $fid $sepline

  chan close $fid

}

# ------------------------------------------------------------------------------
proc mem_load {} {

  global APPDATA HP15 DM15 status stack istack storage MAT prgstat PRGM FLAG

  if {![::prdoc::Discard]} { return }

# Load memory file
  set fnam "$APPDATA(HOME)/$APPDATA(memfile)"

# Move Linux and macOS config files created up to version 4.3.00 to new location
  if {$::tcl_platform(platform) ne "windows"} {
    set mme "$::env(HOME)/.hp-15c.mme"
    if {![file exists $fnam] && [file exists $mme]} {
      catch {file rename $mme $fnam}
    }
    set hst "$::env(HOME)/.hp-15c.hst"
    set hstnew "$APPDATA(HOME)/$APPDATA(hstfile)"
    if {![file exists $hstnew] && [file exists $hst]} {
      catch {file rename $hst $hstnew}
    }
  }

  if {[file exists $fnam]} {
    if {[catch {source -encoding unicode $fnam} err]} {
      error_handler [list FILEIO EFMT $fnam $err]
    }
  }

# Update to return-stack notation introduced in version 4.3.00
  if {$prgstat(rtnadr) eq {0}} {
    set prgstat(rtnadr) {}
  }

# Clean obsolete, changed or moved settings
  if {[info exists HP15(tagbold)]} { ;# Moved to prdoc::CONF
    set ::prdoc::CONF(tagbold) $HP15(tagbold)
    array unset HP15 tagbold
  }
  if {[info exists HP15(tagcolour)]} { ;# Moved to prdoc::CONF
    set ::prdoc::CONF(tagcolour) $HP15(tagcolour)
    array unset HP15 tagcolour
  }
  if {[info exists HP15(matseperator)]} { ;# Typo fix
    set HP15(matseparator) $HP15(matseperator)
    array unset HP15 matseperator
  }

  # Handling changed due to native macOS serial port driver
  if {[info exists DM15(dm15cc_port)] && $DM15(dm15cc_port) eq "-" } {
    set HP15(dm15cc_port) ""
  }

  preferences_apply_tcl
  ::prdoc::Reload

# Refresh status line
  set_status NIL

}

# ------------------------------------------------------------------------------
proc mem_reset {} {

  global HP15 HP15_DEF status STATUS_DEF prgstat prgstat_DEF PRGM
  global FLAG curdisp

  if {![::prdoc::Discard]} { return }

  unset status
  array set status [array get STATUS_DEF]

  set HP15(dataregs) $HP15_DEF(dataregs)
  set HP15(freebytes) $HP15_DEF(freebytes)
  set HP15(poolregsfree) $HP15_DEF(poolregsfree)
  set HP15(prgmregs) $HP15_DEF(prgmregs)
  set HP15(prgmname) $HP15_DEF(prgmname)

  array set prgstat [array get prgstat_DEF]
  set PRGM {{}}

  array unset ::prdoc::DESC
  ::prdoc::Reload

  clearall
  matrix_init
  mem_recalc
  for {set ff 0} {$ff < 10} {incr ff} {set FLAG($ff) 0}

# Refresh status line
  set_status NIL
  set status(error) 1
  set curdisp "  PR ERROR"

}

# ------------------------------------------------------------------------------
# File history section
# ------------------------------------------------------------------------------
proc hist_menu { mn } {

  global HP15 filehist

  $mn delete 0 end

  set idx 0
  foreach fnam [::history::get filehist] {
    set sts normal
    if {![file exists $fnam]} {
      set sts disabled
    }
    $mn add command -command "prgm_open \"$fnam\"" -state $sts
    if {!$HP15(histfullpath)} {
      set fnam [file tail $fnam]
    }
    if {$idx < 10} {
      $mn entryconfigure $idx -label "$idx  $fnam" -underline 0
    } else {
      $mn entryconfigure $idx -label "    $fnam"
    }
    incr idx
  }
  if {$idx > 0} {
    $mn add separator
    $mn add command -label [mc menu.recentpurge] -command "hist_purge"
    $mn add command -label [mc menu.clearrecent] -command "hist_clear"
  } else {
    $mn add command -label [mc pdocu.notavailable] -state disabled
  }

}

# ------------------------------------------------------------------------------
proc hist_add { fnam } {

  global filehist

  ::history::add filehist $fnam

}

# ------------------------------------------------------------------------------
proc hist_clear {} {

  global APPDATA filehist

  set answer [tk_messageBox -type okcancel -icon question -default ok \
        -title $APPDATA(title) -message "[mc menu.clearrecent.confirm]"]
  if {$answer eq "ok"} {
    ::history::clear filehist
  }

}

# ------------------------------------------------------------------------------
proc hist_purge {} {

  global filehist

  foreach fnam [::history::get filehist] {
    if {![file exists $fnam]} {
      ::history::del filehist $fnam
    }
  }

}

# ------------------------------------------------------------------------------
proc hist_save {} {

  global APPDATA filehist

  set sepline "# [string repeat - 78]"
  set fid [open "$APPDATA(HOME)/$APPDATA(hstfile)" {RDWR CREAT TRUNC}]

  puts $fid $sepline
  puts $fid "# $APPDATA(model) Recent Programs"
  puts $fid "$sepline\n"

  puts $fid "set entries {"
  foreach ii [::history::get filehist] {
    puts $fid "  {$ii}"
  }
  puts $fid "}"

  chan close $fid

}

# ------------------------------------------------------------------------------
proc hist_load {} {

  global APPDATA HP15 filehist

  set fnam "$APPDATA(HOME)/$APPDATA(hstfile)"
  ::history::size filehist $HP15(histsize)
  if {[file exists $fnam]} {
    if {[catch {source $fnam} err]} {
      error_handler [list FILEIO EFMT $fnam $err]
    } else {
      foreach ee [lreverse $entries] {
        ::history::add filehist $ee
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc check_docu {} {

  global APPDATA PRGM

  set rc "ok"

  if {![info exists ::prdoc::DESC(T)] || $::prdoc::DESC(T) eq ""} {
    append nodoc "   - [mc pdocu.prgmtitle]\n"
  }
  if {![info exists ::prdoc::DESC(D)] || $::prdoc::DESC(D) eq ""} {
    append nodoc "   - [mc pdocu.usage]\n"
  }
  if {[llength $PRGM] == 1} {
    append nodoc "   - [mc gen.program]\n"
  }

  if {[info exists nodoc]} {
    set rc [tk_messageBox -type okcancel -icon question -default cancel \
      -title $APPDATA(title) \
      -message "[mc pdocu.missing1]\n\n$nodoc\n[mc pdocu.missing2]" ]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc prgm_save { {deftype ""} } {

  global APPDATA HP15 prgmtype

# Program directory and name
  if {![file exists $HP15(prgmdir)]} {
    set HP15(prgmdir) $APPDATA(HOME)
  }
  if {$HP15(prgmname) eq ""} {
    if {[info exists ::prdoc::DESC(T)] && $::prdoc::DESC(T) ne ""} {
      set fnam [string range $::prdoc::DESC(T) 0 39]
    } else {
      set fnam [mc gen.new]
    }
  } else {
    set fnam $HP15(prgmname)
  }

# Configure save file dialogue
  if {$deftype eq ""} {
    set deftype [mc app.ext15c]
  }
  set prgmtype $deftype

  if {$::tcl_platform(os) eq "Darwin" && [file extension $fnam] eq ""} {
    set tt [lsearch -index 0 -inline $APPDATA(filetypes_out) $deftype]
    if {$tt != -1} {
      append fnam [lindex [lindex $tt 1] 0]
    }
  }

  set opts {}
  if {$::tcl_platform(platform) eq "windows"} {
    lappend opts -defaultextension ".15c"
  }
# WA-MAC: usage of initialdir is broken in 8.6.6
  if {!([package vcompare [info patchlevel] "8.6.6"] == 0 && \
      $::tcl_platform(os) eq "Darwin")} {
    lappend opts -initialdir $HP15(prgmdir)
  }

# User dialogue
  set fnam [tk_getSaveFile -title [mc sys.saveprgrm $APPDATA(title)] \
    -filetypes $APPDATA(filetypes_out) -typevariable ::prgmtype \
    -initialfile $fnam {*}$opts]

# Save the file
  if {$fnam ne ""} {
    if {[file extension $fnam] eq ""} {
      set tt [lsearch -index 0 -inline $APPDATA(filetypes_out) $prgmtype]
      if {$tt != -1} {
        append fnam [lindex [lindex $tt 1] 0]
      }
    }
    if {[file extension $fnam] in {".htm" ".html"} && [check_docu] ne "ok"} {
      return
    }

    if {[prgm_write $fnam]} {
      set HP15(prgmdir) [file dirname $fnam]
      set HP15(prgmname) [file rootname [file tail $fnam]]
      if {[file extension $fnam] eq ".15c"} {
        hist_add $fnam
      }
    }

  }

  set prgmtype ""

# WA-MAC: After system dialogues, the focus is not always on the gui since 8.6.8
  if {$::tcl_platform(os) eq "Darwin"} {
    focus -force .gui
  }

}

# ------------------------------------------------------------------------------
proc prgm_write { fnam } {

  if {[catch {set fid [open $fnam {RDWR CREAT TRUNC}]}]} {
    catch {chan close $fid}
    error_handler [list FILEIO ECREATE $fnam]
    return 0
  }

  if {[catch {
    if {[file extension $fnam] in {".htm" ".html"}} {
      prgm_write_html $fid
    } else {
      prgm_write_std $fid
    }

    chan close $fid
  }]} {
    set ec [lindex $::errorCode 2]
    catch {chan close $fid}
    error_handler [list FILEIO $ec $fnam]
    return 0
  }

  return 1

}

# ------------------------------------------------------------------------------
proc prgm_write_std { fid } {

  global APPDATA HP15 PRGM

  set sepline "# [string repeat - 78]"
  ::prdoc::Purge $PRGM

  if {$HP15(prgmstounicode)} {
    chan configure $fid -encoding unicode
    puts -nonewline $fid "\uFEFF"
  }

  puts $fid $sepline
  puts $fid "# $APPDATA(model) Simulator program"
  puts $fid "# Created with version $APPDATA(version)"
  puts $fid $sepline

  ::prdoc::Analyse $PRGM
  if {[info exists ::prdoc::DESC(T)]} {
    puts $fid "#T:$::prdoc::DESC(T)"
  }
  if {[info exists ::prdoc::DESC(D)]} {
    foreach ll [split $::prdoc::DESC(D) "\n"] {
      puts $fid "#D:$ll"
    }
  }
  foreach tt {L R F} {
    foreach pm $::prdoc::MARKS($tt) {
      if {[info exists ::prdoc::DESC($tt$pm)]} {
        puts $fid "#$tt$pm:$::prdoc::DESC($tt$pm)"
      }
    }
  }
  puts $fid "$sepline\n"
  puts $fid [prgm_decode "   "]
  puts -nonewline $fid $sepline

}

# ------------------------------------------------------------------------------
proc prgm_decode { {lpad ""} }  {

global PRGM

  set rc ""
  set ii 0
  foreach ll $PRGM {
    set seq ""
    foreach cc [split $ll "_"] {
      append seq [format {%3s} $cc]
    }
    append rc [format "%s%03d {%12s } %s\n" $lpad $ii $seq \
      [format_mnemonic $ll 0]]
    incr ii
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc html_key_class { seq key } {

  global HP15

  set css ""

  if {$HP15(html_bwkeys)} {
    if {$key in {42 43}} {
      set css HP15CBWfgKey
    } else {
      set css HP15CBWKey
    }
  } elseif {$key eq "u"} {
    set css HP15CfKeyLabel
  } elseif {$key eq "42"} {
    set css HP15CfKey
  } elseif {$key eq "43"} {
    set css HP15CgKey
  } elseif {$seq eq "43 30"} {
     set css HP15CgKeyLabel
  } else {
    switch [lookup_label_ind $seq $key] {
      4 {set css HP15CfKeyLabel}
      5 {set css HP15CKey}
      6 {set css HP15CgKeyLabel}
    }
  }

  return $css

}

# ------------------------------------------------------------------------------
proc prgm_write_colgroup { fid colcnt fmt } {

  for {set cc 0} {$cc < $colcnt} {incr cc} {
    puts $fid [::html::openTag colgroup]
    foreach cl $fmt {
      puts $fid "<col style=\"width: $cl;\">"
    }
    puts $fid [::html::closeTag]
  }

}

# ------------------------------------------------------------------------------
proc prgm_write_table_header { fid colcnt fmt data } {

  puts $fid [::html::openTag thead]
  puts $fid [::html::openTag tr]

  for {set cc 0} {$cc < $colcnt} {incr cc} {
    foreach cl $fmt dd $data {
      puts $fid [::html::cell class=\"$cl\" $dd th]
    }
  }

  puts $fid [::html::closeTag]
  puts $fid [::html::closeTag]

}

# ------------------------------------------------------------------------------
proc prgm_write_table_body { fid colcnt fmt data } {

  set rowcnt [expr int(ceil([llength $data]/($colcnt*1.0)))]

  puts $fid [::html::openTag tbody]

  for {set rr 0} {$rr < $rowcnt} {incr rr} {
    puts $fid [::html::openTag tr]
    for {set cc 0} {$cc < $colcnt} {incr cc} {
      set kk [expr $rr + ($cc * $rowcnt)]
      if {$kk < [llength $data]} {
        set dd [lindex $data $kk]
        foreach cl $fmt cdd $dd {
          puts $fid [::html::cell class=\"$cl\" $cdd]
        }
      } else {
        foreach cl $fmt {
          puts $fid [::html::cell {} ""]
        }
      }
    }
    puts $fid [::html::closeTag] ;# tr
  }

  puts $fid [::html::closeTag] ;# tbody

}

# ------------------------------------------------------------------------------
proc prgm_write_html { fid } {

  global status APPDATA HP15 PRGM

  set cssDef "$APPDATA(basedir)/css/HP-15C_css.txt"
  array set COLGROUPS {
    1 {"4em" "70.5em" "0.5em"}
    2 {"4em" "33em" "0.5em"}
    3 {"4em" "20.5em" "0.5em"}
  }

  array set COLCLASS {
    C.L.E    {HP15CTblCentered HP15CTblLeft HP15CTblEmpty}
    C.RC.L.E {HP15CTblCentered HP15CTblRightCode HP15CTblLeft HP15CTblEmpty}
    H.H.E    {HP15CTblHead HP15CTblHead HP15CTblEmpty}
    H.H.HE   {HP15CTblHead HP15CTblHead HP15CTblHeadEmpty}
    H.H.H.HE {HP15CTblHead HP15CTblHead HP15CTblHead HP15CTblHeadEmpty}
  }

  ::prdoc::Purge $PRGM

# Save current status when "Structure in English" is on
  set locale_save [mclocale]
  set dot $status(dot)
  if {$HP15(html_en) == 1} {
    mclocale en_gb
    if {$dot ne ","} exchange_seps
  }

  if {[file exists $cssDef]} {
    set fin [open $cssDef {RDONLY}]
    set css [chan read $fin]
    chan close $fin
  } else {
    mclocale $locale_save
    error_handler [list FILEIO $cssDef [mc err.nofile]]
    return
  }

  chan configure $fid -encoding utf-8

#HTML Header
  ::html::init [list html.lang [string map {_ -} [mclocale]]]
  puts $fid {<!DOCTYPE html>}
  ::html::headTag \
    {meta http-equiv="content-type" content="text/html; charset=UTF-8"}
  ::html::headTag "style>\n$css</style"
  puts $fid [::html::head $HP15(prgmname)]
  puts $fid [::html::openTag body]

# Title and description
  if {[info exists ::prdoc::DESC(T)]} {
    puts -nonewline $fid [::html::h1 $::prdoc::DESC(T)]
  }

  if {[info exists ::prdoc::DESC(D)]} {
    puts -nonewline $fid [::html::h2 [mc pdocu.description]]
    set preformatted 0
    foreach ln [split $::prdoc::DESC(D) "\n"] {
# Now newlines for <pre>formatted text
      if {[string first "<pre>" $ln] > -1} { set preformatted 1 }
      if {[string first "</pre>" $ln] > -1} { set preformatted 0 }
      if {[regexp {</*(h\d|ol(“[^”]*”|'[^’]*’|[^'”>])*|ul|li)> *$} $ln] == 0 &&
        $preformatted == 0} {
        append ln "<br>"
      }
      if {$HP15(html_bwkeys)} {
        regsub -all {class="HP15C[^"]+"} $ln {class="HP15CBWKey"} ln
      }
      puts $fid $ln
    }
  }
  if {[llength $::prdoc::MARKS(L)] > 0 || [llength $::prdoc::MARKS(R)] > 0 || \
    [llength $::prdoc::MARKS(F)] > 0} {
    puts -nonewline $fid [::html::h2 [mc pdocu.resources]]
  }

# Labels
  if {[llength $::prdoc::MARKS(L)] > 0} {
    set colcnt [expr int(max(min(ceil([llength $::prdoc::MARKS(L)]/8.0),3), 1))]
    puts -nonewline $fid [::html::h3 [mc gen.labels]]
    puts $fid [::html::openTag table {class="HP15CTblLayout"}]

    prgm_write_colgroup $fid $colcnt $COLGROUPS($colcnt)

    prgm_write_table_header $fid $colcnt $COLCLASS(H.H.HE) \
      [list [mc gen.name] [mc pdocu.description] ""]

    set data {}
    foreach mm $::prdoc::MARKS(L) {
      if {[info exists ::prdoc::DESC(L$mm)]} {
        set md $::prdoc::DESC(L$mm)
      } else {
        set md ""
      }
      lappend data [list [format_mark $mm] $md ""]
    }
    prgm_write_table_body $fid $colcnt $COLCLASS(C.L.E) $data

    puts $fid [::html::closeTag]
  }

# Storage registers
  if {[llength $::prdoc::MARKS(R)] > 0} {
    set colcnt [expr int(max(min(ceil([llength $::prdoc::MARKS(R)]/8.0),3), 1))]
    puts -nonewline $fid [::html::h3 [mc gen.regs]]
    puts $fid [::html::openTag table {class="HP15CTblLayout"}]

    prgm_write_colgroup $fid $colcnt $COLGROUPS($colcnt)

    prgm_write_table_header $fid $colcnt $COLCLASS(H.H.HE)\
      [list [mc gen.name] [mc pdocu.description] ""]

    set data {}
    foreach rr $::prdoc::MARKS(R) {
      if {[info exists ::prdoc::DESC(R$rr)]} {
        set rd $::prdoc::DESC(R$rr)
      } else {
        set rd ""
      }
      lappend data [list [format_mark $rr] $rd ""]
    }
    prgm_write_table_body $fid $colcnt $COLCLASS(C.L.E) $data

    puts $fid [::html::closeTag]
  }

# Flags
  if {[llength $::prdoc::MARKS(F)] > 0} {
    puts -nonewline $fid [::html::h3 [mc gen.flags]]
    puts $fid [::html::openTag table {class="HP15CTblLayout"}]

    prgm_write_colgroup $fid 1 [list "5em" "69.5em" "0.5em"]

    prgm_write_table_header $fid 1 $COLCLASS(H.H.E) \
      [list [mc gen.number] [mc pdocu.description]]

    set data {}
    foreach rr $::prdoc::MARKS(F) {
      if {[info exists ::prdoc::DESC(F$rr)]} {
        set fd $::prdoc::DESC(F$rr)
      } else {
        set fd ""
      }
      lappend data [list $rr $fd]
    }
    prgm_write_table_body $fid 1 $COLCLASS(C.L.E) $data

    puts $fid [::html::closeTag]
  }

# Listing
  if {[llength $PRGM] > 1} {
    if {$HP15(html_1column)} {
      set colcnt 1
    } else {
      set colcnt [expr max(min(ceil([llength $PRGM]/25.0),3), 1)]
    }
    puts -nonewline $fid [::html::h2 [mc gen.program]]
    puts $fid [::html::openTag table {class="HP15CTblLayout"}]

    prgm_write_colgroup $fid $colcnt [list "3.5em" "7em" "14em" "0.5em"]

    prgm_write_table_header $fid $colcnt $COLCLASS(H.H.H.HE) \
      [list [mc gen.line] [mc gen.display] [mc gen.keyseq] {}]

    set data {}
    set line 0
    foreach ll $PRGM {
      set user [lindex {"" "u"} [regsub "_u$" $ll {} ks]]
      set code $user[format_keyseq $ks 9]
      set seq ""
      set cv ""
      if {$user eq "u"} {
        append cv {<span class="} [html_key_class $seq "u"] {">} \
          [::html::html_entities [lookup_keyname $seq "u"]] {</span> }
      }
      foreach key [split $ks "_"] {
        append cv {<span class="} [html_key_class $seq $key] {">} \
          [::html::html_entities [lookup_keyname $seq $key]] {</span> }
        set seq [string trim "$seq $key"]
      }
      if {$HP15(html_indent) && $cv ne "" && !([string match "42_21_*" $ll] || $ll eq "43_32")} {
        set cv "<span class=\"HP15CindentSeq\">[string trim $cv]</span>"
      }
      lappend data [list [format "%03d" $line] $code $cv ""]
      incr line
    }
    prgm_write_table_body $fid $colcnt $COLCLASS(C.RC.L.E) $data

    puts $fid [::html::closeTag] ;# table
  }

  mclocale $locale_save
  if {$dot ne $status(dot)} exchange_seps

}

# ------------------------------------------------------------------------------
proc prgm_getfile {} {

  global APPDATA HP15

  if {![file exists $HP15(prgmdir)]} {
    set HP15(prgmdir) $APPDATA(HOME)
  }

  set fnam [tk_getOpenFile -title [mc sys.openprgrm $APPDATA(title)] \
    -filetypes $APPDATA(filetypes_in) -initialdir $HP15(prgmdir) \
    -defaultextension ".15c"]

# WA-MAC: After system dialogues, the focus is not always on the gui since 8.6.8
  if {$::tcl_platform(os) eq "Darwin"} {
    focus -force .gui
  }

  if {$fnam ne ""} {
    prgm_open $fnam
  }

}

# ------------------------------------------------------------------------------
proc prgm_load { data } {

  global HP15 status FLAG prgstat PRGM

  set PRGMtmp {}
  array set DESCtmp {}

  set lcnt 0
  if {[catch {
    foreach curline [split $data "\n"] {
      incr lcnt
      set curline [string trim $curline]
      if {[string length $curline] > 0 && [string index $curline 0] ne "#"} {
        if {[regexp "\{(.*)\}" $curline all step] == 0} { error }
        regsub {[,\.]([0-9])} [string trim $step] {48 \1} step
        regsub -all { +} [string trim $step] {_} step
        if {[lookup_keyseq $step] eq "" && [llength $PRGMtmp] > 0} { error }
        lappend PRGMtmp $step
        unset step
      } elseif {[regexp {#D:(.*)} $curline ign vv] > 0} {
        append DESCtmp(D) "[regsub -all "\\\\n" $vv "\u000A"]\n"
      } elseif {[regexp {#([TFLR][^:]*):(.*)} $curline ign tt vv] > 0} {
         set DESCtmp($tt) $vv
      }
    }
  }]} {
    return -code error -errorcode {INVCMD} \
      -options [list -lineno $lcnt -linetext $curline]
  }

# Insert empty step 000 if first step is not empty
  if {[lindex $PRGMtmp 0] ne ""} {set PRGMtmp [linsert $PRGMtmp 0 ""]}

  set pbytes [prgm_len $PRGMtmp]
  set maxbytes [expr ($HP15(totregs) - $FLAG(8)*5 - $HP15(dataregs) + 1) * 7]

  if {$pbytes <= $maxbytes && [llength $PRGMtmp] <= 1000} {
    set prgstat(curline) 0
    set prgstat(rtnadr) {}
    set PRGM $PRGMtmp
    array unset ::prdoc::DESC
    array set ::prdoc::DESC [array get DESCtmp]

    if {$status(PRGM)} {
      show_curline
    } elseif {$status(error)} {
      set status(error) 0
      show_x
    }
    ::prdoc::Reload
  } else {
    return -code error -errorcode {ADDRESS}
  }

}

# ------------------------------------------------------------------------------
proc prgm_open { fnam } {

  global HP15

# Check for changed but unsaved documentation
  if {![::prdoc::Discard]} { return }

  if {[catch {set fid [open $fnam {RDONLY}]}]} {
    set ec [lindex $::errorCode 1]
    catch {chan close $fid}
    error_handler [list FILEIO $ec $fnam]
    return
  }

# Check file for a BOM
  set bom [chan read $fid 3]
  chan seek $fid 0
# Check for UTF-16 LE BOM "FF FE"
  if {[string first "\377\376" $bom] == 0} {
    chan configure $fid -encoding unicode
    chan seek $fid 2
# Check for UTF-8 BOM "EF BB BF"
  } elseif {[string first "\357\273\277" $bom] == 0} {
    chan configure $fid -encoding utf-8
    chan seek $fid 3
  }

# Read file
  if {[catch {
    set fdata [read $fid]
    chan close $fid
  }]} {
    catch {chan close $fid}
    error_handler [list FILEIO $::errorCode $fnam 0]
    return
  }

  if {[catch {
# Load data to program and description
    prgm_load $fdata

    set HP15(prgmname) [file rootname [file tail $fnam]]
    hist_add $fnam
    if {$HP15(docuonload)} {::prdoc::Edit}
  } err opts ]} {
    switch $::errorCode {
      INVCMD {
        error_handler [list FILEIO INVCMD [dict get $opts -linetext] [dict get $opts -lineno] $fnam]
      }
      ADDRESS {
        error_handler ADDRESS
      }
    }
  }

  set HP15(prgmdir) [file dirname $fnam]

}

# ------------------------------------------------------------------------------
proc DM15_do_ok { wid mode md } {

  global DM15 dm15tmp

  foreach cc {prgm sto mat stack flags} {
    set DM15($md\_$cc) $dm15tmp($md\_$cc)
  }

  destroy $wid

  DM15_$mode

}

# ------------------------------------------------------------------------------
proc DM15_do { mode } {

  global APPDATA DM15 dm15tmp

  if {!$DM15(dm15cc)} {
    return
  }

  if {$DM15(interactive)} {
    toplevel .dm15cc
    wm attributes .dm15cc -alpha 0.0
    wm title .dm15cc $APPDATA(appname)

    if {$mode eq "read"} {
      set ftxt [mc menu.dm15cc.read]
      set md "r"
    } else {
      set ftxt [mc menu.dm15cc.write]
      set md "w"
    }

    foreach cc {prgm sto mat stack flags} {
      set dm15tmp($md\_$cc) $DM15($md\_$cc)
    }

    set fpo .dm15cc.outer
    ttk::frame $fpo -relief flat

# Data frame
    set fpo $fpo.data
    ttk::labelframe $fpo -text " $ftxt " -padding {20 0 20 0}

    ttk::label $fpo.lblprgm -text [mc gen.program]
    ttk::label $fpo.lblsto -text [mc gen.regs]
    ttk::label $fpo.lblmat -text [mc gen.matrices]
    ttk::label $fpo.lblstack -text [mc gen.stack]
    ttk::label $fpo.lblflags -text [mc gen.flags]

    ttk::checkbutton $fpo.prgm -variable dm15tmp($md\_prgm)
    ttk::checkbutton $fpo.sto -variable dm15tmp($md\_sto)
    ttk::checkbutton $fpo.mat -variable dm15tmp($md\_mat)
    ttk::checkbutton $fpo.stack -variable dm15tmp($md\_stack)
    ttk::checkbutton $fpo.flags -variable dm15tmp($md\_flags)

    grid $fpo.lblprgm -row 1 -column 0 -sticky w -padx 10
    grid $fpo.lblsto -row 2 -column 0 -sticky w -padx 10
    grid $fpo.lblmat -row 3 -column 0 -sticky w -padx 10
    grid $fpo.lblstack -row 4 -column 0 -sticky w -padx 10
    grid $fpo.lblflags -row 5 -column 0 -sticky w -padx 10

    grid $fpo.prgm -row 1 -column 1 -padx 20 -sticky w
    grid $fpo.sto -row 2 -column 1 -padx 20 -sticky w
    grid $fpo.mat -row 3 -column 1 -padx 20 -sticky w
    grid $fpo.stack -row 4 -column 1 -padx 20 -sticky w
    grid $fpo.flags -row 5 -column 1 -padx 20 -sticky w

    grid $fpo -row 0 -column 0 -padx 5 -pady 5 -sticky nswe

# Button frame
    set fbtn .dm15cc.outer.btn
    ttk::frame $fbtn -relief flat -borderwidth 5
    ttk::button $fbtn.action -text [mc gen.$mode] -default active\
      -command "DM15_do_ok .dm15cc $mode $md"
    ttk::button $fbtn.cancel -text [mc gen.cancel] -command "destroy_modal .dm15cc"

    grid $fbtn.action -row 0 -column 0 -padx 5 -pady 5 -sticky e
    grid $fbtn.cancel -row 0 -column 1 -padx 5 -pady 5 -sticky e
    grid $fbtn -row 1 -column 0 -sticky nsew
    grid columnconfigure $fbtn 0 -weight 1

    bind .dm15cc <Return> "$fbtn.action invoke"
    bind .dm15cc <Escape> "$fbtn.cancel invoke"

    grid .dm15cc.outer -row 0 -column 0 -sticky nswe

    update
    set px [expr [winfo screenwidth .dm15cc]/2 - [winfo width .dm15cc]/2]
    set py [expr [winfo screenheight .dm15cc]/2 - [winfo height .dm15cc]/2]
    wm geometry .dm15cc +$px+$py
    wm resizable .dm15cc false false

    raise .dm15cc
    grab .dm15cc
    focus .dm15cc
    wm attributes .dm15cc -alpha 1.0

  } else {
    DM15_$mode
  }

}

# ------------------------------------------------------------------------------
proc DM15_chkport {} {

  global DM15

  if {$DM15(spdriver) eq "native" && $DM15(dm15cc_port) eq ""} {
    error "[mc dm15cc.err.noport]"
  }

}

# ------------------------------------------------------------------------------
proc DM15_read {} {

  global APPDATA HP15 DM15 status FLAG prgstat PRGM

  if {[catch {
    DM15_chkport

    ::DM15::Open $DM15(dm15cc_port)
    ::DM15::ReadMem
    ::DM15::Close

    set MemInfo [::DM15::MemInfo]
    if {[dict get $MemInfo totregs] > $HP15(totregs)} {
      error "[mc dm15cc.fw.notcompatible [dict get $MemInfo totregs]]"
    }

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message "[mc menu.dm15cc.read]:\n$errMsg"
    return
  }

  if {[catch {

    if {$DM15(r_flags)} {::DM15::GetFlags FLAG}
    if {$DM15(r_stack)} {
      if {$FLAG(8)} {
        ::DM15::GetStack ::stack ::istack
      } else {
        ::DM15::GetStack ::stack
      }
    }
    if {$DM15(r_sto)} {
      if {[dict get $MemInfo dataregs] > $HP15(dataregs)} {
        error "[mc dm15cc.storagecnt]"
      }
      ::DM15::GetStorage ::storage
    }

    if {$DM15(r_mat)} {
      if {[dict get $MemInfo matregs] > $HP15(poolregsfree)} {
        error "[mc dm15cc.matsize]"
      }
      ::DM15::GetMatrices ::MAT
      set mid [expr [scan [::DM15::GetResultMatrix] "%c"] - 64]
      set status(result) [Descriptor $mid]
    }

    if {$DM15(r_prgm)} {
      if {[dict get $MemInfo prgmregs] > $HP15(poolregsfree)+$HP15(prgmregs)} {
        error "[mc prgm.tolarge]"
      }
      set PRGM [::DM15::GetPrgm]

      set prgstat(curline) 0
      set prgstat(interrupt) 0
      set HP15(prgmname) ""
      set prgstat(running) 0
      set prgstat(rtnadr) {}
      array unset ::prdoc::DESC
      mem_recalc
      if {$status(PRGM)} {
        show_curline
      }
    }

    if {!$status(PRGM)} {show_x}

    tk_messageBox -type ok -icon info -default ok -title $APPDATA(title) \
      -message "[mc menu.dm15cc.read]:\n[mc dm15cc.ok.read]"
  } errMsg]} {
    tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
      -message "[mc menu.dm15cc.read]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc DM15_write {} {

  global APPDATA HP15 DM15 status PRGM

  if {[catch {
    DM15_chkport

    ::DM15::Open $DM15(dm15cc_port)
    ::DM15::ReadMem

    set MemInfo [::DM15::MemInfo]

    if {$DM15(w_flags)} {::DM15::SetFlags ::FLAG}
    if {$DM15(w_stack)} {::DM15::SetStack ::stack ::istack}

    if {$DM15(w_sto)} {
      if {$HP15(dataregs) > [dict get $MemInfo dataregs]} {
        error "[mc dm15cc.storagecnt]"
      }
      ::DM15::SetStorage ::storage
    }

    if {$DM15(w_mat)} {
      if {[matrix_mem] > [dict get $MemInfo poolregs]-[dict get $MemInfo prgmregs]} {
        error "[mc dm15cc.matsize]"
      }
      ::DM15::SetMatrices ::MAT
      ::DM15::SetResultMatrix [format "%c" [expr 64+[string index $status(result) 1]]]
    }

    if {$DM15(w_prgm)} {
      if {$HP15(prgmregs) > [dict get $MemInfo poolregs]} {
        error "[mc prgm.tolarge]"
      }
      ::DM15::SetPrgm ::PRGM
    }

    ::DM15::WriteMem
    ::DM15::Close

    tk_messageBox -type ok -icon info -default ok -title $APPDATA(title) \
      -message "[mc menu.dm15cc.write]:\n[mc dm15cc.ok.write]"

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message "[mc menu.dm15cc.write]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc DM15_synctime {} {

  global APPDATA DM15 DM15synching

  if {$DM15synching} { return }

  if {[catch {
    DM15_chkport

    set DM15synching 1
    ::DM15::Open $DM15(dm15cc_port)
    ::DM15::WriteTime
    set DM15status [::DM15::ReadStatus]
    ::DM15::Close
    DM15_timefmtd [dict get $DM15status datetime]
    set DM15synching 0

  } errMsg]} {
    ::DM15::Close
    set DM15synching 0
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message "[mc menu.dm15cc.write]:\n$errMsg"
  }

}

# ------------------------------------------------------------------------------
proc DM15_timefmtd { tval } {

  global DM15timefmtd

  set pct [clock seconds]
  set tdelta [format {(%+ds)} [expr $tval - $pct]]
  set DM15timefmtd "[clock format $tval -format {%Y-%m-%d %H:%M:%S}] $tdelta"

}

# ------------------------------------------------------------------------------
proc DM15_sysinfo {} {

  global APPDATA HP15 DM15

  if {!$DM15(dm15cc)} {
    return
  }

  if {[catch {
    DM15_chkport

    ::DM15::Open $DM15(dm15cc_port)
    set DM15status [::DM15::ReadStatus]
    ::DM15::Close

  } errMsg]} {
    ::DM15::Close
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message "[mc menu.dm15cc.read]:\n$errMsg"
    return
  }

  toplevel .dm15si
  wm title .dm15si [mc $APPDATA(title)]
  wm attributes .dm15si -alpha 0.0

# Status frame
  set fps .dm15si.status
  ttk::labelframe $fps -text " [mc menu.dm15.sysinfo] "

# Firmware
  ttk::label $fps.lblfwt -text "[mc dm15cc.fw]: "
  array set fwregs { DM15 64 DM15_M80 128 DM15_M1B 229 }
  set fwt [dict get $DM15status fwtype]
  ttk::label $fps.fwt -text "$fwt ($fwregs($fwt) [mc gen.regs])"

  ttk::label $fps.lblfwv -text "[mc gen.version]: "
  ttk::label $fps.fwv -text [dict get $DM15status fwversion]

  grid $fps.lblfwt -row 0 -column 0 -padx 10 -sticky w
  grid $fps.fwt -row 0 -column 1 -sticky w
  grid $fps.lblfwv -row 1 -column 0 -padx 10 -sticky w
  grid $fps.fwv -row 1 -column 1 -sticky w

# Time
  if {[dict exists $DM15status datetime]} {
    DM15_timefmtd [dict get $DM15status datetime]

    ttk::label $fps.lbltime -text "[mc dm15cc.datetime]: "
    ttk::label $fps.time -textvariable DM15timefmtd
    ttk::button $fps.sync -text "[mc dm15cc.sync]" -command "DM15_synctime"

    grid $fps.lbltime -row 2 -column 0 -padx 10 -sticky w
    grid $fps.time -row 2 -column 1 -sticky w
    grid $fps.sync -row 2 -column 2 -padx 10 -sticky w
  }

# Battery
  if {[dict exists $DM15status battery]} {
    ttk::label $fps.lblbat -text "[mc gen.voltage]: "
    set bat [dict get $DM15status battery]
    foreach {blevel bp} [list 2800 ">50%" 2700 ">25%" 2300 ">10%" 0 "<10%"] {
      if {$bat >= $blevel} {
        set bt $bp
        break
      }
    }
    ttk::label $fps.bat -text "$bat mV ([mc dm15.remainpower] $bt)"

    grid $fps.lblbat -row 3 -column 0 -padx 10 -sticky w
    grid $fps.bat -row 3 -column 1 -sticky w
  }

  grid $fps -row 0 -column 0 -padx 5 -pady 5 -sticky nwse

# Button frame
  set fbtn .dm15si.btn
  ttk::frame $fbtn -relief flat -borderwidth 5
  ttk::button $fbtn.ok -text [mc gen.ok] -command "destroy_modal .dm15si"

  grid $fbtn.ok -row 0 -column 1 -padx 5 -pady 5 -sticky e
  grid $fbtn -row 1 -column 0 -sticky nwse
  grid columnconfigure $fbtn 0 -weight 1

  bind .dm15si <Return> "$fbtn.ok invoke"
  bind .dm15si <Escape> "$fbtn.ok invoke"

  update
  set px [expr [winfo screenwidth .dm15si]/2 - [winfo width .dm15si]/2]
  set py [expr [winfo screenheight .dm15si]/2 - [winfo height .dm15si]/2]
  wm geometry .dm15si +$px+$py
  wm resizable .dm15si false false

  raise .dm15si
  grab .dm15si
  focus .dm15si
  wm attributes .dm15si -alpha 1.0

}

# ------------------------------------------------------------------------------
proc clipboard_set { fmt } {

  if {[tk windowingsystem] eq "x11"} {
    selection handle -selection PRIMARY . "clipboard_transfer $fmt"
    selection own -selection PRIMARY .
    selection handle -selection CLIPBOARD . "clipboard_transfer $fmt"
    selection own -selection CLIPBOARD .
  } else {
    clipboard clear
    clipboard append [clipboard_transfer $fmt 0 2000]
  }

}

# ------------------------------------------------------------------------------
proc clipboard_transfer { fmt offset maxchars } {

  global HP15 status stack istack FLAG

  set rc ""
  if {$status(PRGM) && $HP15(clpbrdprgm)} {
    set rc [prgm_decode]
  } elseif {[isDescriptor $stack(x)]} {
    set rc [matrix_copy $stack(x) $fmt]
  } else {
    if {$FLAG(8)} {
      set sign ""
      if {$istack(x) >= 0.0} { set sign "+" }
    }
    if {$fmt} {
      set rc [regsub { +} [string trim [format_number $stack(x)]] "e"]
      if {$FLAG(8)} {
        append rc "$sign[regsub { +} [string trim [format_number $istack(x)]] "e"]i"
      }
    } elseif {$HP15(clpbrdc)} {
      set rc $stack(x)
      if {$FLAG(8)} {
        append rc "$sign$istack(x)i"
      }
    } else {
      set rc [string map ". $status(comma)" $stack(x)]
      if {$FLAG(8)} {
        append rc "$sign[string map ". $status(comma)" $istack(x)]i"
      }
    }
  }

  return $rc

}

# ----------------------------------------------------------------------------
proc clipboard_get {} {

  global status stack

# On Windows only CLIPBOARD selection exists. On UNIX most applications use
# PRIMARY selection, some use CLIPBOARD (or both). We will check for both...
  if {[catch {set clpbrd [selection get -selection PRIMARY]}]} {
    catch {set clpbrd [selection get -selection CLIPBOARD]}
  }
  if {![info exists clpbrd]} { return }

  if {$status(PRGM)} {
    if {[catch {
# Load data to program and description
      prgm_load $clpbrd
      set HP15(prgmname) ""
    } err opts ]} {
      switch $::errorCode {
        INVCMD {
          error_handler [list FILEIO CLPBRD [dict get $opts -linetext] [dict get $opts -lineno]]
        }
        ADDRESS {
          error_handler ADDRESS
        }
      }
    }
  } else {
# Use only first "line"
    if {[set nlpos [string first "\n" $clpbrd]] > -1} {
      set clpbrd [string range $clpbrd 0 [expr $nlpos-1]]
    }
# Remove chars from the beginning/end of the line that can't be part of a number
    regsub {^[^.,\-+0-9]*} $clpbrd {} clpbrd
    regsub {[^.,0-9]*$} $clpbrd {} clpbrd

# Normalize input
    set clpbrd [string map {" " "" ' "" E e} $clpbrd]
    regsub {^\-0+} $clpbrd {-} clpbrd
    regsub {^0+} $clpbrd {} clpbrd

    if {[string length $clpbrd] > 0} {
# Check for numbers with comma AND period
      regexp {^[^e]*} $clpbrd mantissa
      set cpos [string last , $mantissa]
      set ppos [string last . $mantissa]
      if {$cpos > -1 && $ppos > -1} {
        if {$cpos > $ppos} {
          set clpbrd [string map {. "" , .} $clpbrd]
        } else {
          set clpbrd [string map {, ""} $clpbrd]
        }
      } else {
        if {$cpos != [string first , $mantissa]} {
          set clpbrd [string map {, ""} $clpbrd]
        }
        set clpbrd [string map {, .} $clpbrd]
        if {$ppos != [string first . $mantissa]} {
          set clpbrd [string map {. ""} $clpbrd]
        }
      }

      if {[string is double $clpbrd]} {
        if {!$status(liftlock)} {lift}
        set status(num) 1
        set status(liftlock) 0
        set stack(x) $clpbrd
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc exchange_seps {} {

  global status

  set tmp $status(comma)
  set status(comma) $status(dot)
  set status(dot) $tmp
  if {!$status(error)} {
    disp_refresh
  }

}

# ------------------------------------------------------------------------------
proc url_open { url } {

  global APPDATA HP15

  if {[tk windowingsystem] eq "win32" && \
    [string first "start" $HP15(browser)] > 0} {
    set command "$HP15(browser) {} [list $url]"
  } else {
    set command "\"$HP15(browser)\" [list $url]"
  }
  if {[catch {exec {*}$command &} exerr]} {
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message "[mc app.openurlerror]\n$exerr"
  }

}

# ------------------------------------------------------------------------------
proc back_side {} {

  global APPDATA LAYOUT ERRORS TEST MATFUNCS

  if {[winfo exists .back]} {
    .gui delete backside
    destroy .back
    .gui itemconfigure guiwin -state normal
    return
  }

# Base are Microsoft Fonts normal 556x352
  set xfactor [expr [winfo width .]/556.0]
  set yfactor [expr [winfo height .]/352.0]

  set fnscale [expr $xfactor*66.0/[font measure "Tahoma 10" "1234567890"]]
  set bfn "Tahoma [expr round(7*$fnscale)]"
  set bfnd "Tahoma [expr round(20*$fnscale)]"
  set bfnb "Tahoma [expr round(9*$fnscale)]"
  set bfni "Tahoma [expr round(7*$fnscale)] italic"
  set bfns "Tahoma [expr round(5*$fnscale)]"
  set bfnis "Tahoma [expr round(5*$fnscale)] italic"

  canvas .back -width [winfo width .] -height [winfo height .] \
    -background $LAYOUT(keypad_bg) -highlightthickness 0

  set lh 14
  set lh2 [expr $lh/2]
  set lh4 [expr $lh/4]
  set lw 14
  set lw2 [expr $lh/2]
  set lw4 [expr $lh/4]

  set xp1 8
  set xp2 [expr $xp1 + 62]
  set xp3 [expr $xp1 + 141]
  set xp4 [expr $xp1 + 307]
  set yp1 50
  set yp2 [expr $yp1+4*$lh+$lh2]
  set yp3 [expr $yp1+8*$lh+$lh2]


  .back create text $xp4 [expr $yp1-2*$lh] \
    -text "G E R M A N Y" -anchor e -justify center -fill #585858 -font $bfnb
  .back create text [expr $xp4+10*$lw] [expr $yp1-2*$lh] \
    -text [split $APPDATA(SerialNo) ""] \
    -anchor center -justify center -fill #585858 -font $bfnb

# Summation results
  set SUMRES {
    "   n" "\u2211 x" "\u2211 x\u00B2" "\u2211 y" "\u2211 y\u00B2" "\u2211 xy"
  }

 .back create rectangle $xp1 $yp3 \
   [expr $xp1+4*$lw] [expr $yp3+7*$lh] -outline grey80 -width 2
 .back create line $xp1 [expr $yp3+$lh] [expr $xp1+4*$lw] [expr $yp3+$lh] \
   -fill grey80

 .back create text [expr $xp1+2*$lw] [expr $yp3+$lh2] \
   -text "\u2211" -anchor center -justify center -fill grey80 -font $bfnb

  set yp [expr $yp3+$lh+$lh2]
  set idx 2
  foreach tt $SUMRES {
    .back create text [expr $xp1+$lw4] $yp \
      -text $tt -anchor w -justify left -fill grey80 -font $bfn
    .back create text [expr $xp1+2*$lw-$lw4] $yp \
      -text "\u2192" -anchor w -justify left -fill grey80 -font $bfn
    .back create text [expr $xp1+3*$lw-$lw4] $yp \
      -text "R" -anchor w -justify left -fill grey80 -font $bfn
    .back create text [expr $xp1+3*$lw+$lw4] [expr $yp+$lh4] \
      -text $idx -anchor w -justify left -fill grey80 -font $bfns
    incr yp [expr $lh-$lh/8]
    incr idx
  }

# Loop description
  set xd 52
  set xd2 [expr $xd/2]
  .back create rectangle $xp3 $yp1 \
    [expr $xp3+3*$xd+$lw4] [expr $yp1+8*$lh] -outline grey80 -width 2
  .back create text [expr $xp3+$lw4+$xd+$xd2] [expr $yp1+$lh2] \
    -text "R = nnnnn.xxxyy" -anchor center -justify center -fill grey80 \
    -font $bfn

  for {set ii 0} {$ii < 3} {incr ii} {
    .back create rectangle [expr $xp3+$lw4+$xd*$ii] [expr $yp1+$lh+$lh4] \
      [expr $xp3+$xd*(1+$ii)] [expr $yp1+2*$lh+$lh2] -outline grey80
  }
  set xp [expr $xp3+$lw4+$xd2]
  foreach {t1 t2} {"nnnnn+yy" "\u2264\u2009xxx" "nnnnn\u00B1yy" ">\u2009xxx" \
    "nnnnn\u2212yy" "\u2264\u2009xxx"} {
    .back create text $xp [expr $yp1+2*$lh-$lh2] \
      -text $t1 -anchor center -justify center -fill grey80 -font $bfn
    .back create text $xp [expr $yp1+2*$lh] \
      -text $t2 -anchor center -justify center -fill grey80 -font $bfn
    incr xp $xd
  }

  set yp [expr $yp1+3*$lh]
  for {set ii 0} {$ii < 4} {incr ii} {
    .back create rectangle [expr $xp3+$xd2-$lw4] [expr $yp+$ii*$lh] \
      [expr $xp3+$xd] [expr $yp+$lh*(1+$ii)] -outline grey80
    .back create rectangle [expr $xp3+$lw4+2*$xd] [expr $yp+$ii*$lh] \
      [expr $xp3+$lw2+2*$xd+$xd2] [expr $yp+$lh*(1+$ii)] -outline grey80
  }
  .back create text [expr $xp3+$xd2+$lw-$lw4] [expr $yp+$lh+$lh2] \
    -text "\[ISG\]" -anchor center -justify center -fill grey80 -font $bfn
  .back create text [expr $xp3+2*$xd+$lw+$lw4] [expr $yp+$lh+$lh2] \
    -text "\[DSE\]" -anchor center -justify center -fill grey80 -font $bfn

  .back create line [expr $xp3+$lw] [expr $yp1+2*$lh+$lh2] \
    [expr $xp3+$lw] [expr $yp1+7*$lh+$lh2] -arrow last -fill grey80 \
    -arrowshape {5p 5p 2p}

  .back create line [expr $xp3+$xd+$lw2] [expr $yp1+2*$lh+$lh2] \
    [expr $xp3+$xd+$lw2] [expr $yp1+5*$lh] -fill grey80
  .back create arc [expr $xp3+$xd] [expr $yp1+5*$lh] \
    [expr $xp3+$xd+$lw] [expr $yp1+6*$lh+$lh4] -outline grey80 -start -90 \
    -extent 180 -style arc -dash {4 1}
  .back create line [expr $xp3+$xd+$lw2] [expr $yp1+6*$lh+$lh4] \
    [expr $xp3+$xd+$lw2] [expr $yp1+7*$lh+$lh2] -fill grey80 -arrow last \
    -arrowshape {5p 5p 2p}

  .back create line [expr $xp3+2*$xd-$lw2] [expr $yp1+2*$lh+$lh2] \
    [expr $xp3+2*$xd-$lw2] [expr $yp1+7*$lh+$lh2] -fill grey80 -arrow last \
    -arrowshape {5p 5p 2p}

  .back create line [expr $xp3+$lw] [expr $yp1+2*$lh+$lh2] \
    [expr $xp3+$lw] [expr $yp1+7*$lh+$lh2] -fill grey80 -arrow last \
    -arrowshape {5p 5p 2p}


  .back create line [expr $xp3+3*$xd-$lw2] [expr $yp1+2*$lh+$lh2] \
    [expr $xp3+3*$xd-$lw2] [expr $yp1+5*$lh] -fill grey80
  .back create arc [expr $xp3+3*$xd-$lw] [expr $yp1+5*$lh] \
    [expr $xp3+3*$xd] [expr $yp1+6*$lh+$lh4] -outline grey80 -start -90 \
    -extent 180 -style arc -dash {4 1}
  .back create line [expr $xp3+3*$xd-$lw2] [expr $yp1+6*$lh+$lh4] \
    [expr $xp3+3*$xd-$lw2] [expr $yp1+7*$lh+$lh2] -fill grey80 \
    -arrow last -arrowshape {5p 5p 2p}

# Conversion constants
  .back create rectangle $xp4 $yp1 \
    [expr $xp4+8*$lw+$lw2] [expr $yp1+4*$lh] -outline grey80 -width 2
  set yp [expr $yp1+$lh2]
  foreach {t1 t2} {"cm \u00F7 2.54" "in" "kg \u2715 2.204622622" "lb" \
    "\u2113 \u00F7 3.785411784" "gal" "\u2103 \u2715 1.8 \u271B 32" \
    "\u2109"} {
    .back create text [expr $xp4+$lw2] $yp -text $t1 -anchor w \
      -justify left -fill grey80 -font $bfn
    .back create text [expr $xp4+5.5*$lw+$lw2] $yp -text "\u2192" -anchor w \
      -justify left -fill grey80 -font $bfn
    .back create text [expr $xp4+7*$lw] $yp -text $t2 -anchor w \
      -justify left -fill grey80 -font $bfn
    .back create line $xp4 [expr $yp+$lh2] \
      [expr $xp4+8*$lw+$lw2] [expr $yp+$lh2] -fill grey80
    incr yp $lh
  }

# Conversion functions
  set CONVERS {
    "[\u2192P]" "r" "\u3B8"
    "[\u2192R]" "x" "y"
    "[x\u0305]" "x\u0305" "y\u0305"
    "[s]" "sx" "sy"
    "[\u0177,r]" "\u0177" "r"
    "[L.R.]" "B" "A"
    "[RCL][\u2211+]" "\u2211x" "\u2211y"
    "[%]" "" "y"
    "[\u0394%]" "" "y"
  }

  set rh [expr $yp3+10*$lh+$lh4]
  .back create rectangle $xp2 $yp3 [expr $xp2+17*$lw] $rh \
    -outline grey80 -width 2

  set yp [expr $yp3+$lh2]
  .back create text [expr $xp2+4*$lw+$lw2] $yp -text "x" -anchor center \
    -justify center -fill grey80 -font $bfnb
  .back create text [expr $xp2+7*$lw] $yp -text "y" -anchor center \
    -justify center -fill grey80 -font $bfnb
  foreach {t1 t2 t3} $CONVERS {
    incr yp $lh
    .back create text [expr $xp2+$lw+$lw2] $yp -text $t1 -anchor center \
      -justify center -fill grey80 -font $bfn
    .back create text [expr $xp2+4*$lw+$lw2] $yp -text $t2 -anchor center \
      -justify center -fill grey80 -font $bfni
    .back create text [expr $xp2+7*$lw] $yp -text $t3 -anchor center \
      -justify center -fill grey80 -font $bfni
    .back create line $xp2 [expr $yp-$lh2] [expr $xp2+8*$lw] \
      [expr $yp-$lh2] -fill grey80
  }

  .back create text [expr $xp2+4*$lw+$lw2] [expr $yp3+8*$lh+$lh2] \
    -text "x \u00B7 y\n100" -anchor center \
    -justify center -fill grey80 -font $bfns
  .back create line [expr $xp2+4*$lw] [expr $yp3+8*$lh+$lh2] \
     [expr $xp2+5*$lw] [expr $yp3+8*$lh+$lh2] -fill grey80
  .back create text [expr $xp2+4*$lw-$lw4] [expr $yp3+9*$lh+$lh2] \
    -text "x \u2212 y\ny" -anchor center -justify center -fill grey80 \
    -font $bfns
  .back create line [expr $xp2+3*$lw+$lw4] [expr $yp3+9*$lh+$lh2] \
     [expr $xp2+4*$lw+$lw2] [expr $yp3+9*$lh+$lh2] -fill grey80
  .back create text [expr $xp2+5*$lw+$lw4] [expr $yp3+10*$lh-$lw2] \
    -text "\u2715100" -anchor center -justify center -fill grey80 -font $bfns

  .back create line [expr $xp2+3*$lw] $yp3 [expr $xp2+3*$lw] $rh -fill grey80
  .back create line [expr $xp2+6*$lw] $yp3 [expr $xp2+6*$lw] $rh -fill grey80
  .back create line [expr $xp2+8*$lw] $yp3 [expr $xp2+8*$lw] $rh -fill grey80

# Graphics
  .back create line [expr $xp2+10*$lw-$lw2] [expr $yp3+4*$lh+$lh2] \
    [expr $xp2+16*$lw] [expr $yp3+4*$lh+$lh2] -fill grey80
  .back create line [expr $xp2+10*$lw-$lw4] [expr $yp3+4*$lh+$lh2] \
    [expr $xp2+10*$lw-$lw4] [expr $yp3+$lh2] -fill grey80
  .back create line [expr $xp2+10*$lw-$lw4] [expr $yp3+4*$lh+$lh2] \
    [expr $xp2+16*$lw] [expr $yp3+$lh] -fill grey80
  .back create line [expr $xp2+10*$lw-$lw4] [expr $yp3+$lh] \
    [expr $xp2+16*$lw] [expr $yp3+$lh] \
      [expr $xp2+16*$lw] [expr $yp3+4*$lh+$lh2] -fill grey80 -dash {4 1}
  .back create text [expr $xp2+13*$lw] [expr $yp3+$lh2] -text "x" \
    -fill grey80 -font $bfn
  .back create text [expr $xp2+16*$lw+$lw2] [expr $yp3+2*$lh+$lh2] \
    -text "y" -fill grey80 -font $bfn
  .back create text [expr $xp2+12*$lw+$lw2] [expr $yp3+2*$lh+$lh2] \
    -text "r" -fill grey80 -font $bfn
  .back create text [expr $xp2+14*$lw+$lw2] [expr $yp3+3*$lh+$lh2] \
    -text "\u03B8" -fill grey80 -font $bfn
  .back create arc [expr $xp3-5*$lw] [expr $yp3-2*$lh+$lh2] \
    [expr $xp2+15*$lw] [expr $yp3+10*$lh+$lh2] -outline grey80 -start 0 \
    -extent 25 -style arc
   .back create text [expr $xp2+9*$lw-$lw4] [expr $yp3+2*$lh] \
     -text "\} \u2192" -fill grey80 -font $bfnb


  .back create line [expr $xp2+10*$lw-$lw2] [expr $yp3+9*$lh+$lh4] \
    [expr $xp2+16*$lw] [expr $yp3+9*$lh+$lh4] -fill grey80
  .back create line [expr $xp2+10*$lw-$lw4] [expr $yp3+9*$lh+$lh4] \
    [expr $xp2+10*$lw-$lw4] [expr $yp3+6*$lh-$lh2] -fill grey80

  .back create line [expr $xp2+9*$lw+$lw2] [expr $yp3+9*$lh] \
    [expr $xp2+16*$lw] [expr $yp3+6*$lh-$lh2] -fill grey80
  .back create oval [expr $xp2+10*$lw-$lw4] [expr $yp3+9*$lh-$lw4] \
    [expr $xp2+10*$lw-$lw4] [expr $yp3+9*$lh-$lw4] -outline grey80 -width 3
  .back create oval [expr $xp2+11*$lw+$lw4] [expr $yp3+8*$lh] \
    [expr $xp2+11*$lw+$lw4] [expr $yp3+8*$lh] -outline grey80 -width 3
  .back create oval [expr $xp2+15*$lw] [expr $yp3+6*$lh] \
    [expr $xp2+15*$lw] [expr $yp3+6*$lh] -outline grey80 -width 3
  .back create line [expr $xp2+11*$lw+$lw4] [expr $yp3+8*$lh] \
    [expr $xp2+15*$lw] [expr $yp3+8*$lh] \
      [expr $xp2+15*$lw] [expr $yp3+6*$lh] -fill grey80 -dash {4 1}
  .back create text [expr $xp2+13*$lw] [expr $yp3+8*$lh+$lh2] -text "x" \
    -fill grey80 -font $bfn
  .back create text [expr $xp2+15*$lw+$lw2] [expr $yp3+7*$lh] -text "y" \
    -fill grey80 -font $bfn
  .back create text [expr $xp2+11*$lw+$lw2] [expr $yp3+6*$lh] \
    -text "A=y/x" -fill grey80 -font $bfni
  .back create text [expr $xp2+10*$lw+$lw2] [expr $yp3+9*$lh-$lh4] \
    -text "B" -fill grey80 -font $bfni
   .back create text [expr $xp2+9*$lw-$lw4] [expr $yp3+6*$lh+$lh2] \
     -text "\} \u2192" -fill grey80 -font $bfnb

# Errors
  for {set ii [expr $yp2+$lh]} {$ii < $yp2+$lh*12} {incr ii $lh} {
    .back create line $xp4 $ii [expr $xp4+16.5*$lw] $ii -fill grey80
  }

  .back create line $xp4 [expr $yp2+$lh*12] \
    [expr $xp4+10.5*$lw] [expr $yp2+$lh*12] -fill grey80
  .back create line [expr $xp4+$lw] [expr $yp2+$lh] \
    [expr $xp4+$lw] [expr $yp2+13*$lh] -fill grey80
  .back create line [expr $xp4+10.5*$lw] [expr $yp2+$lh] \
    [expr $xp4+10.5*$lw] [expr $yp2+13*$lh] -fill grey80
  .back create line [expr $xp4+12.5*$lw] [expr $yp2+$lh] \
    [expr $xp4+12.5*$lw] [expr $yp2+11*$lh] -fill grey80

  .back create text [expr $xp4+6*$lw] [expr $yp2+$lh2] -text "ERROR" \
    -anchor center -justify center -fill grey80 -font $bfnb
  for {set ii 0} {$ii < 12} {incr ii} {
    .back create text [expr $xp4+$lw2]  [expr $yp2+$lh*(1+$ii)+$lh2] \
      -text $ii -anchor center -justify center -fill grey80 -font $bfn
  }

  set ii 1
  foreach ll $ERRORS {
    .back create text [expr $xp4+0.8*$lw+$lw2] [expr $yp2+$lh*$ii+$lh2] \
      -text $ll -anchor w -justify left -fill grey80 -font $bfn
    incr ii
  }

# Test
  .back create text [expr $xp4+11.5*$lw] [expr $yp2+$lh2] -text "TEST" \
    -anchor center -justify center -fill grey80 -font $bfnb
  set ii 1
  foreach ll $TEST {
    .back create text [expr $xp4+11.5*$lw] [expr $yp2+$lh*$ii+$lh2] \
      -text $ll -anchor center -justify center -fill grey80 -font $bfn
    incr ii
    if {$ii == 11} break
  }
  set yp [expr $yp2+$lh]

# Matrix
  .back create line [expr $xp4+13*$lw] $yp [expr $xp4+16.5*$lw] $yp -fill grey80
  .back create text [expr $xp4+14.5*$lw] [expr $yp2+$lh2] -text "MATRIX" \
    -anchor center -justify center -fill grey80 -font $bfnb

  set ii 1
  foreach ll $MATFUNCS {
    .back create text [expr $xp4+12.8*$lw] [expr $yp2+$lh*$ii+$lh2] \
      -text $ll -anchor w -justify left -fill grey80 -font $bfn
    incr ii
  }

# Outer frame
  .back create polygon $xp4 $yp2 [expr $xp4+16.5*$lw] $yp2 \
    [expr $xp4+16.5*$lw] [expr $yp2+11*$lh] [expr $xp4+10.5*$lw] [expr $yp2+11*$lh] \
    [expr $xp4+10.5*$lw] [expr $yp2+13*$lh] $xp4 [expr $yp2+13*$lh] $xp4 $yp2 \
    [expr $xp4+$lw] $yp2 -outline grey80 -width 2 -fill ""

  .back scale all 0 0 $xfactor $yfactor

  .gui create window 0 0 -window .back -anchor nw -tags backside

# WA-MAC: Force refresh of windows on canvas by hiding and setting to normal
  if {$::tcl_platform(os) eq "Darwin"} {
    .gui itemconfigure guiwin -state hidden
  }
  bind .back <Button> back_side
  bind .back <Key> back_side

  focus .back

}

# ------------------------------------------------------------------------------
proc help { topic } {

  global APPDATA HP15

  switch $topic {
    simulator {
      set helpfile "$APPDATA(docdir)/index.htm"
    }
    prgm {
      set helpfile "$HP15(prgmdir)/$HP15(prgmname).htm"
    }
  }
  catch {set helpfile [file nativename [lindex [glob "$helpfile*"] 0]]}

  if {[string length $HP15(browser)] == 0} {
    set msg [mc help.nobrowser]
    preferences
  } elseif {$topic eq "prgm" && $HP15(prgmname) eq ""} {
    set msg [mc help.nohelpfile]
  } elseif {![file exists $helpfile]} {
    set msg "[mc help.notfound]\n$helpfile"
  }

  if {[info exists msg]} {
    tk_messageBox -type ok -icon error -default ok \
      -title $APPDATA(title) -message $msg
    if {[winfo exists .prefs]} {focus .prefs}
  } else {
    url_open $helpfile
  }

}

# ------------------------------------------------------------------------------
proc show_on_options { trigger } {

  global HP15 DM15 status

  if {[winfo exists .onm]} {destroy .onm}
  if {[winfo exists .omn.mem]} {destroy .omn.mem}

  menu .onm -title [mc menu.options] -postcommand "menu_post .onm"

  .onm add command -label [mc menu.openprgm] -command "prgm_getfile"
  menu .onm.recent -postcommand "hist_menu .onm.recent"
  .onm add cascade -label [mc menu.recent] -menu .onm.recent
  .onm add command -label [mc menu.saveprgm] -command "prgm_save"
  .onm add separator
  .onm add command -label [mc menu.prgmdocu] -command "::prdoc::Edit"
  .onm add command -label [mc menu.htmlhelp] -command "help prgm"
  .onm add separator

  if {$status(PRGM)} {
    set st disabled
  } else {
    set st normal
  }
  .onm add command -label [mc menu.clearall] -command "clearall" -state $st
  menu .onm.mem -title [mc menu.mem]
  .onm.mem add command -label [mc menu.loadmem] -command "mem_load"
  .onm.mem add command -label [mc menu.savemem] -command "mem_save"
  .onm.mem add command -label [mc menu.resetmem] -command "mem_reset"
  .onm add cascade -label [mc menu.memory] -menu .onm.mem

  if {$DM15(dm15cc)} {
    menu .onm.dm15cc -title [mc menu.dm15cc]
    .onm.dm15cc add command -label [mc gen.read] -command "DM15_do read"
    .onm.dm15cc add command -label [mc gen.write] -command "DM15_do write"
    .onm.dm15cc add separator
    .onm.dm15cc add command -label [mc dm15.sysinfo] -command "DM15_sysinfo"
    .onm add cascade -label [mc menu.dm15cc] -menu .onm.dm15cc
  }
  .onm add separator

  .onm add checkbutton -label [mc menu.ontop] -command "gui_top" \
    -variable HP15(wm_top)
  .onm add command -label [mc menu.flipseps] -command "exchange_seps"
  .onm add command -label [mc menu.prefs] -command "preferences"
  .onm add separator
  .onm add command -label [mc gen.help] -command "help simulator"
  .onm add command -label [mc menu.backside] -command "back_side"
  .onm add command -label [mc menu.about] -command "about"
  .onm add separator
  .onm add command -label [mc gen.exit] -command "exit"

  if {$trigger eq "MOUSE"} {
    tk_popup .onm [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .onm [guipos btn_18_t x2] [guipos dspbg y2]
  }

}

# ------------------------------------------------------------------------------
proc mbar_draw { mstruct } {

  global APPDATA

  if {[info exists APPDATA(mbar)]} {
    foreach child [winfo children $APPDATA(mbar)] {
      destroy $child
    }
    $APPDATA(mbar) delete 0 end
  }

  foreach mm $mstruct {
    foreach {mt mn ml ma mc mo} $mm {
      if {[dict exists $mo visible] && ![set [dict get $mo visible]]} {
        continue
      }
      set tma ""
      foreach mp $ma {
        if {[string index $mp 0] eq "$"} {
          set mp [set [string range $mp 1 end]]
        }
        set tma $tma[mc {*}$mp]
      }
      switch $mt {
        menubar {
          if {![info exists APPDATA(mbar)]} {
            menu $mn -relief flat
            set APPDATA(mbar) $mn
          }
        }
        menu {
          set nm [join $mn ""]
          menu $nm -tearoff 0 -relief flat -postcommand "$ma $nm"
          [lindex $mn 0] add cascade -label [mc $ml] -menu $nm
        }
        cmd {
          $APPDATA(mbar)$mn add command -label [mc $ml] -accelerator $tma \
            -command $mc
        }
        chkbtn {
          $APPDATA(mbar)$mn add checkbutton -label [mc $ml] -accelerator $tma \
            -command $mc {*}[dict get $mo options]
        }
        sep {
          $APPDATA(mbar)$mn add separator
        }
      }
    }
  }

# WA-MAC: 'Hide' menus to prevent macOS from adding additional own entries
  if {[tk windowingsystem] eq "aqua"} {
    for {set ii 1} {$ii <= [$APPDATA(mbar) index last]} {incr ii} {
      $APPDATA(mbar) entryconfigure $ii \
        -label "\u200B[$APPDATA(mbar) entrycget $ii -label]"
    }
  }

}

# ------------------------------------------------------------------------------
proc mbar_show { {toggle 0} } {

  global APPDATA HP15

  wm resizable . false true

  if {[tk windowingsystem] eq "aqua"} {
    set HP15(showmenu) 1
  } elseif {$toggle} {
    set HP15(showmenu) [expr !$HP15(showmenu)]
  }
  if {$HP15(showmenu)} {
    . configure -menu $APPDATA(mbar)
  } else {
    . configure -menu {}
  }

  wm resizable . false false
  update idletasks

}

# ------------------------------------------------------------------------------
proc menu_post { mn } {

  global HP15 status

  for {set ii 0} {[$mn index end] ne "none" && $ii <= [$mn index end]} {incr ii} {
    set lbl ""
    catch {set lbl [$mn entrycget $ii -label]} {}
    if {[string match "[mc menu.htmlhelp]*" $lbl]} {
      if {$HP15(prgmname) eq ""} {
        set pn [mc pdocu.notavailable]
      } elseif {[string length $HP15(prgmname)] > 50} {
        set pn "[string range $HP15(prgmname) 0 49]\u2026"
      } else {
        set pn $HP15(prgmname)
      }
      if {[llength [glob -nocomplain "$HP15(prgmdir)/$HP15(prgmname).htm*"]] > 0} {
        set st normal
      } else {
        set st disabled
      }
      $mn entryconfigure $ii -state $st -label "[mc menu.htmlhelp]: $pn"
    } elseif {[mc menu.clearall] == $lbl} {
      if {$status(PRGM)} {
        $mn entryconfigure $ii -state disabled
      } else {
        $mn entryconfigure $ii -state normal
      }
    } elseif {$lbl in [list [mc menu.backside] [mc menu.frontside]]} {
      if {[winfo exists .back]} {
        set nlbl [mc menu.frontside]
      } else {
        set nlbl [mc menu.backside]
      }
      $mn entryconfigure $ii -label $nlbl
    }
  }

}

# ------------------------------------------------------------------------------
proc guipos { tag kk } {

  set status [.gui bbox $tag]
  set rc 0

  switch $kk {
    x1 {set rc [expr [winfo rootx .gui]+[lindex $status 0]+1]}
    x2 {set rc [expr [winfo rootx .gui]+[lindex $status 2]-1]}
    y1 {set rc [expr [winfo rooty .gui]+[lindex $status 1]+1]}
    y2 {set rc [expr [winfo rooty .gui]+[lindex $status 3]-1]}
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc matrix_menu { name mat } {

  global LAYOUT HP15 status

  set mm .mm$name
  if {[winfo exists $mm]} {destroy $mm}

  set cols [::matrix::Cols $mat]
  set rows [::matrix::Rows $mat]

  menu $mm -title [mc gen$mm] -font $LAYOUT(FnMenu)
  $mm configure -activeforeground [$mm cget -foreground] \
    -activebackground [$mm cget -background]

  if {$cols == 0 || $rows == 0} {
    $mm add command -label [format_descriptor $name]
  } else {
    if {$HP15(matstyle) eq "cell"} {
      set rr 1
      foreach row $mat {
        set cc 0
        set txt " "
        foreach elem $row {
          append txt [format "$rr$status(dot)[incr cc]:%15s  " [format_number $elem]]
        }
        $mm add command -label $txt -hidemargin 1
        incr rr
      }
    } else {
      set head [string range [format_descriptor $name] 0 3]
      for {set cc 0} {$cc < $cols} {incr cc} {
        append head [format "%2s%15s" [expr $cc+1] " "]
      }
      $mm add command -label $head -hidemargin 1
      set rr 0
      foreach row $mat {
        set cc 1
        set txt "[format "%2s \u2502" [incr rr]]"
        foreach elem $row {
          append txt [format "%15s" [format_number $elem]]
          if {$cc < $cols} {
            append txt [format " \u2502"]
          }
          incr cc
        }
        $mm add command -label $txt -hidemargin 1
      }
    }
  }

  return $mm

}

# ------------------------------------------------------------------------------
proc show_storage { function trigger } {

  global HP15

  if {[tk windowingsystem] eq "aqua" && !$HP15(osxmenus)} {
    show_storage_macos $function $trigger
  } else {
    show_storage_std $function $trigger
  }

}

# ------------------------------------------------------------------------------
proc show_storage_std { function trigger } {

  global LAYOUT HP15 storage

  if {[winfo exists .storage]} {destroy .storage}

  menu .storage -title [mc gen.regs] -font $LAYOUT(FnMenu)

  set regmax [expr $HP15(dataregs) < 19 ? $HP15(dataregs) : 19]
  set hgh [expr $HP15(breakstomenu) == 0 ? $regmax+2 : int(ceil($regmax/2.0))+1]

  for {set ii 0} {$ii <= $regmax} {incr ii} {
    if {[isDescriptor $storage($ii)]} {
      set txt [format_descriptor $storage($ii)]
    } else {
      set txt [format_number $storage($ii)]
    }

    set rd ""
    if {$HP15(stomenudesc) && [string length $HP15(prgmname)] > 0 &&
      [info exists ::prdoc::DESC(R$ii)]} {
      if {[string length $::prdoc::DESC(R$ii)] > 25} {
        set rd " [string range $::prdoc::DESC(R$ii) 0 24]\u2026"
      } else {
        set rd " $::prdoc::DESC(R$ii)"
      }
    }
    .storage add command -label [format "R%2s: %14s%s" [format_mark $ii] $txt $rd]
    if {$ii < 10} {
      .storage entryconfigure $ii -underline 2 \
        -command "dispatch_key $function\_$ii"
    } else {
      .storage entryconfigure $ii \
        -command "dispatch_key $function\_48_[expr $ii-10]"
    }
  }

  if {[isDescriptor $storage(I)]} {
    set txt [format_descriptor $storage(I)]
  } else {
    set txt [format_number $storage(I)]
  }
  .storage add command -underline 2 -command "dispatch_key $function\_25" \
    -label [format "R I: %14s" $txt]

  if {$regmax % 2 != 0} {
    incr hgh -1
  }
  .storage entryconfigure $hgh -columnbreak $HP15(breakstomenu)

  if {$trigger eq "MOUSE"} {
    tk_popup .storage [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .storage [guipos btn_$function\_t x1] [guipos btn_$function\_g y1]
  }

}

# ------------------------------------------------------------------------------
proc show_storage_macos { function trigger } {

  global LAYOUT HP15 storage

  set ecfg "-background systemAlternatePrimaryHighlightColor -foreground white"
  set lcfg "-background white -foreground black"

  if {[winfo exists .popup]} {destroy .popup}

  set regmax [expr $HP15(dataregs) < 19 ? $HP15(dataregs) : 19]
  set hgh [expr $HP15(breakstomenu) == 0 ? $regmax+2 : int(ceil($regmax/2.0))+1]
  set wid [expr $HP15(breakstomenu) == 0 ? 22 : 44]

  toplevel .popup
  wm title .popup [mc gen.regs]
  text .popup.text -font $LAYOUT(FnMenu) -spacing1 3 -height $hgh -width $wid
  pack .popup.text -expand yes -fill both

  set line 0
  for {set ii 0} {$ii <= $regmax} {incr ii} {
    incr line
    if {$HP15(breakstomenu) && $ii == $hgh-($regmax % 2)} {
      set line 1
    }
    if {[isDescriptor $storage($ii)]} {
      set txt [format_descriptor $storage($ii)]
    } else {
      set txt [format_number $storage($ii)]
    }
    if {[string length $txt] < 14} {
      append txt " "
    }
    set txt [format " R%2s: %15s " [format_mark $ii] $txt]
    .popup.text insert $line.end $txt R$ii
    if {$ii < 10} {
      .popup.text tag bind R$ii <ButtonPress> \
        "destroy_modal .popup; dispatch_key $function\_$ii"
    } else {
      .popup.text tag bind R$ii <ButtonPress> \
        "destroy_modal .popup; dispatch_key $function\_48_[expr $ii-10]"
    }
    if {$ii + 1 < $hgh} {
      .popup.text insert end "\n"
    }
    .popup.text tag bind R$ii <Enter> ".popup.text tag configure R$ii $ecfg"
    .popup.text tag bind R$ii <Leave> ".popup.text tag configure R$ii $lcfg"
  }

  incr line
  if {[isDescriptor $storage(I)]} {
    set txt [format_descriptor $storage(I)]
  } else {
    set txt [format_number $storage(I)]
  }
  if {[string length $txt] < 14} {
    set txt "$txt "
  }
  set txt [format " R I: %15s " $txt]
  .popup.text insert $line.end [string repeat " " [expr $wid-[string length $txt]]]
  .popup.text insert $line.end $txt RI
  .popup.text tag bind RI <Enter> ".popup.text tag configure RI $ecfg"
  .popup.text tag bind RI <Leave> ".popup.text tag configure RI $lcfg"
  .popup.text tag bind RI <ButtonPress> \
    "destroy_modal .popup; dispatch_key $function\_25"

  .popup.text configure -state disabled \
    -selectforeground black -selectbackground white

  wm transient .popup .
  wm resizable .popup false false
  wm geometry .popup +[guipos btn_$function\_t x1]+[guipos btn_$function\_g y1]

  bind .popup <Escape> "destroy_modal %W"
  bind .popup <FocusOut> "destroy_modal %W"
  wm protocol .popup WM_DELETE_WINDOW "destroy_modal .popup"

  raise .popup
  grab .popup
  focus .popup

}

# ------------------------------------------------------------------------------
proc show_labels { trigger } {

  global HP15 LAYOUT status PRGM

  if {$status(error) || [llength $PRGM] == 0} {
    return
  }

  if {[winfo exists .labels]} {destroy .labels}
  menu .labels -title [mc gen.labels] -font $LAYOUT(FnMenu)

  set albl {}
  set nlbl {}
  for {set ii 0} {$ii < [llength $PRGM]} {incr ii} {
    if {[regexp {42_21_(48_)*([0-9])$} [lindex $PRGM $ii] step dec lbl]} {
      if {$dec ne ""} {
        set cmd 48_$lbl
        incr lbl 10
      } else {
        set cmd $lbl
      }
      lappend nlbl [list $ii $lbl $cmd]
    } elseif {[regexp {42_21_1([1-5])$} [lindex $PRGM $ii] step lbl]} {
      lappend albl [list $ii -$lbl 1$lbl]
    }
  }

  if {$HP15(sortgsb)} {
    set lst [concat [lsort -index 1 -integer -decreasing $albl] \
      [lsort -index 1 -unique -integer $nlbl]]
  } else {
    set lst [lsort -index 0 -unique -integer [concat $albl $nlbl]]
  }

  if {[llength $lst] > 0} {
    foreach ll $lst {
      set lbl [lindex $ll 1]
      set txt "[format_mark $lbl]: "
      if {[info exists prdoc::DESC(L$lbl)]} {
        if {[string index $prdoc::DESC(L$lbl) 0] eq "#"} continue
        append txt $prdoc::DESC(L$lbl)
      }
      .labels add command -label $txt -command "dispatch_key 32_[lindex $ll 2]"
    }

    if {$trigger eq "MOUSE"} {
      tk_popup .labels [winfo pointerx .] [winfo pointery .]
    } else {
      tk_popup .labels [guipos btn_32_t x1] [guipos btn_32_g y1]
    }
  }

}

# ------------------------------------------------------------------------------
proc show_flags { trigger } {

  global LAYOUT status FLAG

  if {[winfo exists .flags]} {destroy .flags}

  menu .flags -title [mc gen.flags] -font $LAYOUT(FnMenu)
  if {$status(PRGM)} {
    set st normal
  } else {
    set st disabled
  }
  for {set ii 0} {$ii < 10} {incr ii} {
    .flags add command -label "F $ii: $FLAG($ii)" -state $st \
      -command "dispatch_key 43_6_$ii"
  }

  if {$trigger eq "MOUSE"} {
    tk_popup .flags [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .flags [guipos btn_29_t x1] [guipos btn_29_g y2]
  }

}

# ------------------------------------------------------------------------------
proc show_content { trigger } {

  global HP15 status

  if {$status(error)} {
    show_error $trigger
  } elseif {$status(PRGM)} {
    show_prgm $trigger
  } else {
    if {[tk windowingsystem] eq "aqua" && !$HP15(osxmenus)} {
      show_stack_macos $trigger
    } else {
      show_stack_std $trigger
    }
  }

}

# ------------------------------------------------------------------------------
proc show_stack_std { trigger } {

  global HP15 LAYOUT FLAG stack istack MAT

  if {[winfo exists .stack]} {destroy .stack}

  menu .stack -title [mc gen.stack] -font $LAYOUT(FnMenu)
  set sts 3
  foreach ii {t z y x LSTx} {
    if {[isDescriptor $stack($ii)]} {
      set txt [format "%5s: %14s" $ii [format_descriptor $stack($ii)]]
    } else {
      set txt [format "%5s: %14s" $ii [format_number $stack($ii)]]
    }
    if {$FLAG(8)} {
      append txt [format " %7s: %14s" i$ii [format_number $istack($ii)]]
    }
    if {[tk windowingsystem] eq "x11"} { append txt " " }
    if {[isDescriptor $stack($ii)] && $HP15(matcascade)} {
      .stack add cascade -label $txt -hidemargin 1 -command "func_roll $sts" \
        -menu [matrix_menu $stack($ii) $MAT($stack($ii))]
    } else {
      .stack add command -label $txt -hidemargin 1 -command "func_roll $sts"
    }
    incr sts -1
  }
  .stack entryconfigure 4 -command "dispatch_key 43_36"
  .stack insert 4 separator

  if {$trigger eq "MOUSE"} {
    tk_popup .stack [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .stack [expr [guipos dspbg x1]+6] [guipos dspbg y2]
  }

}

# ------------------------------------------------------------------------------
proc show_stack_macos { trigger } {

  global LAYOUT FLAG stack istack

  set ecfg "-background systemAlternatePrimaryHighlightColor -foreground white"
  set lcfg "-background white -foreground black"

  if {[winfo exists .popup]} {destroy .popup}

  toplevel .popup
  wm title .popup [mc gen.stack]
  set wid [expr $FLAG(8) == 0 ? 23 : 47]
  text .popup.text -font $LAYOUT(FnMenu) -spacing1 3 -height 6 -width $wid
  pack .popup.text -expand yes -fill both

  set sts 3
  foreach ii {t z y x LSTx} {
    if {[isDescriptor $stack($ii)]} {
      set txt [format "%5s: %14s " $ii [format_descriptor $stack($ii)]]
    } else {
      set txt [format "%5s: %14s " $ii [format_number $stack($ii)]]
    }
    if {$FLAG(8)} {
      append txt [format "%7s: %14s " i$ii [format_number $istack($ii)]]
    }
    .popup.text insert end $txt $ii
    .popup.text tag bind $ii <Enter> ".popup.text tag configure $ii $ecfg"
    .popup.text tag bind $ii <Leave> ".popup.text tag configure $ii $lcfg"
    if {$ii eq "LSTx"} {
      .popup.text tag bind $ii <ButtonPress> "destroy_modal .popup; dispatch_key 43_36"
    } else {
      .popup.text tag bind $ii <ButtonPress> "destroy_modal .popup; func_roll $sts"
      .popup.text insert end " \n"
    }
    incr sts -1
  }
  .popup.text insert 5.0 "[string repeat "\u2500" $wid]\n" sep
  .popup.text configure -state disabled \
    -selectforeground black -selectbackground white

  wm transient .popup .
  wm resizable .popup false false
  if {$trigger eq "MOUSE"} {
    wm geometry .popup +[winfo pointerx .]+[winfo pointery .]
  } else {
    wm geometry .popup +[expr [guipos dspbg x1]+6]+[guipos dspbg y2]
  }

  bind .popup <Escape> "destroy_modal %W"
  bind .popup <FocusOut> "destroy_modal %W"
  wm protocol .popup WM_DELETE_WINDOW "destroy_modal .popup"

  raise .popup
  grab .popup
  focus .popup

}

# ------------------------------------------------------------------------------
proc show_matrix_funcs { trigger } {

  global MATFUNCS

  if {[winfo exists .matfuncs]} {destroy .matfuncs}

  menu .matfuncs -title "MATRIX"
  set ii 0
  foreach mf $MATFUNCS {
    .matfuncs add command -label "$ii:  $mf" -command "dispatch_key 42_16_$ii" \
      -underline 0
    incr ii
  }

  if {$trigger eq "MOUSE"} {
    tk_popup .matfuncs [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .matfuncs [guipos btn_16_f x1] [guipos btn_16_f y2]
  }

}

# ------------------------------------------------------------------------------
proc show_matrix { md trigger item } {

  global HP15

  if {[tk windowingsystem] eq "aqua" && !$HP15(osxmenus)} {
    show_matrix_macos $md $trigger $item
  } else {
    show_matrix_std $md $trigger $item
  }

}

# ------------------------------------------------------------------------------
proc show_matrix_std { md trigger item } {

  global HP15 MAT

  set mm [matrix_menu $md $MAT($md)]
  if {$trigger eq "MOUSE"} {
    tk_popup $mm [guipos $item x1] [expr [guipos $item y2]+2]
  } else {
    tk_popup $mm [expr [guipos $item x1]+6] [expr [guipos $item y2]-2]
  }

}

# ------------------------------------------------------------------------------
proc show_matrix_macos { md trigger item } {

  global LAYOUT HP15 status MAT

  if {[winfo exists .popup]} {destroy .popup}

  set cols [::matrix::Cols $MAT($md)]
  set rows [::matrix::Rows $MAT($md)]

  toplevel .popup
  wm title .popup "[string range [format_descriptor $md] 0 3]"
  text .popup.text -font $LAYOUT(FnMenu) -height $rows -relief raised
  pack .popup.text -expand yes -fill both

  if {$cols == 0 || $rows == 0} {
    .popup.text configure -width 15
    .popup.text insert 0.0 [format_descriptor $md]
  } else {
    if {$HP15(matstyle) eq "cell"} {
      .popup.text configure -width [expr 21*$cols]
      set rr 1
      foreach row $MAT($md) {
        set cc 0
        set txt ""
        foreach elem $row {
          append txt [format " $rr$status(dot)[incr cc]:%15s " [format_number $elem]]
        }
        if {$rr < $rows} {
          append txt "\n"
        }
        .popup.text insert end $txt
        incr rr
      }
    } else {
      .popup.text configure -height [expr $rows+1] -width [expr 17*$cols+3]
      set head "  "
      for {set cc 0} {$cc < $cols} {incr cc} {
        append head [format "   %1s%13s" [expr $cc+1] " "]
      }
      .popup.text insert 0.0 "$head\n"
      set rr 0
      foreach row $MAT($md) {
        set cc 1
        set txt "[format "%2s" [incr rr]]"
        foreach elem $row {
          append txt [format " \u2502%15s" [format_number $elem]]
          incr cc
        }
        if {$rr < $rows} {
          append txt "\n"
        }
        .popup.text insert end $txt
      }
    }
  }
  .popup.text configure -state disabled

  if {$trigger eq "MOUSE"} {
    set px [winfo pointerx .]
    set py [winfo pointery .]
  } else {
    set px [expr [guipos dspbg x1]+6]
    set py [guipos dspbg y2]
  }

  update
  if {$px + [winfo width .popup] > [winfo screenwidth .popup]} {
    set px [expr [winfo screenwidth .popup] - [winfo width .popup] - 20]
  }
  if {$py + [winfo height .popup] + 100 > [winfo screenheight .popup]} {
    set py [expr [winfo screenheight .popup] - [winfo height .popup] - 100]
  }

  wm transient .popup .
  wm resizable .popup false false
  wm geometry .popup +$px+$py

  bind .popup <Escape> "destroy_modal %W"
  bind .popup <FocusOut> "destroy_modal %W"
  bind .popup <ButtonPress> "destroy_modal %W"
  wm protocol .popup WM_DELETE_WINDOW "destroy_modal .popup"

  raise .popup
  grab .popup
  focus .popup

}

# ------------------------------------------------------------------------------
proc show_test_options { trigger } {

  global LAYOUT status TEST

  if {$status(PRGM)} {
    if {[winfo exists .testops]} {destroy .testops}

    menu .testops -title [mc gen.test] -font $LAYOUT(FnMenu)
    for {set ii 0} {$ii < 10} {incr ii} {
      .testops add command -label "$ii: [lindex $TEST $ii]" \
        -command "dispatch_key 43_30_$ii" -underline 0
    }

    if {$trigger eq "MOUSE"} {
      tk_popup .testops [winfo pointerx .] [winfo pointery .]
    } else {
      tk_popup .testops [guipos btn_310_t x1] [guipos btn_310_g y1]
    }
  }

}

# ------------------------------------------------------------------------------
proc show_error { trigger } {

  global ERRORS

  if {[winfo exists .error]} {destroy .error}

  menu .error -title [mc gen.error]
  set ii 0
  foreach me $ERRORS {
    .error add command -label "[format "%2d" $ii]: $me"
    incr ii
  }
  .error add separator
  .error add command -label "98 : [mc gen.file] I/O [mc gen.error]"
  .error add command -label "99 : Tcl/Tk [mc gen.error]"
  .error add command -label "Pr Error : [mc menu.prerror]"

  .error configure -activebackground [.error cget -background]
  .error configure -activeforeground [.error cget -foreground]

  if {$trigger eq "MOUSE"} {
    tk_popup .error [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .error [expr [guipos dspbg x1]+6] [guipos dspbg y2]
  }

}

# ------------------------------------------------------------------------------
proc destroy_modal { wid } {

  grab release $wid
  destroy $wid

}

# ------------------------------------------------------------------------------
proc lift {} {

  global FLAG stack istack

# When lift is called, stack(x) already contains a checked variable.
# For performance reasons we can temporarily disable the checks
  trace remove variable ::stack(y) write chk_range
  set stack(t) $stack(z)
  set stack(z) $stack(y)
  set stack(y) $stack(x)
  trace add variable ::stack(y) write chk_range

  if {$FLAG(8)} {
    trace remove variable ::istack(y) write chk_range
    set istack(t) $istack(z)
    set istack(z) $istack(y)
    set istack(y) $istack(x)
    set istack(x) 0.0
    trace add variable ::istack(y) write chk_range
  }

}

# ------------------------------------------------------------------------------
proc drop {} {

  global FLAG stack istack

# When drop is called, stack(y) already contains a checked variable.
# For performance reasons we can temporarily disable the checks
  trace remove variable ::stack(x) write chk_xreg
  trace remove variable ::stack(y) write chk_range
  set stack(x) $stack(y)
  set stack(y) $stack(z)
  set stack(z) $stack(t)
  trace add variable ::stack(x) write chk_xreg
  trace add variable ::stack(y) write chk_range

  if {$FLAG(8)} {
    trace remove variable ::istack(x) write chk_range
    trace remove variable ::istack(y) write chk_range
    set istack(x) $istack(y)
    set istack(y) $istack(z)
    set istack(z) $istack(t)
    trace add variable ::istack(x) write chk_range
    trace add variable ::istack(y) write chk_range
  }

}

# ------------------------------------------------------------------------------
proc move { from to } {

  global FLAG stack istack

  if {$FLAG(8)} {set istack($to) $istack($from)}
  set stack($to) $stack($from)

}

# ------------------------------------------------------------------------------
proc populate { val } {

  global FLAG stack istack

  foreach jj {x y z t} {
    set stack($jj) $val
  }

  if {$FLAG(8)} {
    foreach jj {x y z t} {
      set istack($jj) $val
    }
  }

}

# ------------------------------------------------------------------------------
proc GETREG { param } {

  global HP15 storage

  if {$param ne "I"} {
    if {$param eq "(i)"} {
      if {[isDescriptor $storage(I)]} {
        return $storage(I)
      } else {
        set param [expr {int($storage(I))}]
      }
    }
    if {($param < 0 || $param > $HP15(dataregs)) && ![isDescriptor $param]} {
      error "" "" {INDEX}
    }
  }

  return $param

}

# ------------------------------------------------------------------------------
proc set_status { st } {

  global status FLAG PI prgstat

  switch $st {
    USER {
      set status(user) [expr !$status(user)]
      set status(f) 0
    }
    f {
      if {!$status(f)} {
        set status(f) [expr !$status(f)]
        set status(g) 0
      }
    }
    g {
      if {!$status(g)} {
        set status(g) [expr !$status(g)]
        set status(f) 0
      }
    }
    fg_off {
      set status(f) 0
      set status(g) 0
    }
    BEGIN {
      set status(BEGIN) [expr !$status(BEGIN)]
    }
    DEG {
      set status(RAD) ""
      set status(rangle) 180.0
    }
    RAD {
      set status(RAD) $st
      set status(rangle) $PI
    }
    GRAD {
      set status(RAD) $st
      set status(rangle) 200.0
    }
    PRGM {
      set status(PRGM) [expr !$status(PRGM)]
    }
  }

  if {$st in {DEG RAD GRAD} && $status(liftlock) > 0} {
    set status(liftlock) 2
  }

  if { !$prgstat(running) && [winfo exists .gui]} {
    .gui itemconfigure suser -text [expr {$status(user) ? "USER" : ""}]
    .gui itemconfigure sf -text [expr {$status(f) ? "f" : " "}]
    .gui itemconfigure sg -text [expr {$status(g) ? "g" : " "}]
    .gui itemconfigure sbegin -text [expr {$status(BEGIN) ? "BEGIN" : " "}]
    .gui itemconfigure srad -text $status(RAD)
    .gui itemconfigure sdmy -text [expr {$status(DMY) ? "D.MY" : " "}]
    .gui itemconfigure scomplex -text [expr {$FLAG(8) ? "C" : " "}]
    .gui itemconfigure sprgm -text [expr {$status(PRGM) ? "PRGM" : ""}]
  }

}

# ------------------------------------------------------------------------------
proc count_digits { var } {

  set rc 0
  foreach cc [split $var {}] {
    if {[string is digit $cc]} {
      incr rc
    } elseif {$cc eq "e"} {
      break
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc func_digit { digit } {

  global status stack istack

  if {$status(num)} {
    if {!$status(liftlock)} {lift}
    if {$status(ixclear)} {set istack(x) 0.0}
    set status(num) 0
    set stack(x) $digit
  } else {
    if {[string first "e" $stack(x)] > 0} {
      regsub {^(.*e[+-])[0-9]([0-9])$} $stack(x) {\1\2} stack(x)
      append stack(x) $digit
    } elseif {[count_digits $stack(x)] < 10} {
      append stack(x) $digit
    }
  }
  set status(liftlock) 0

}

# ------------------------------------------------------------------------------
proc func_point {} {

  global status stack istack

  if {$status(num)} {
    if {!$status(liftlock)} {lift}
    if {$status(ixclear)} {set istack(x) 0.0}
    set status(num) 0
    set stack(x) "0."
  } elseif {[string first "e" $stack(x)] < 0 && [string first "." $stack(x)] < 0} {
    append stack(x) "."
  }
  set status(liftlock) 0

}

# ------------------------------------------------------------------------------
proc func_EEX {} {

  global status stack istack

  if {$status(num)} {
    if {!$status(liftlock)} {lift}
    if {$status(ixclear)} {set istack(x) 0.0}
    set status(num) 0
    set stack(x) "1e+0"
  } elseif {[string first "e" $stack(x)] < 0} {
    if {$stack(x) == 0.0} {
      set stack(x) 1
    } else {
      set mv1 ""
      set mv2 ""
      regexp {^-?([0-9]+)} $stack(x) ignore mv1
      regexp {^-?(0\.0+)} $stack(x) ignore mv2
      if {[string length $mv1] <= 7 && [string length $mv2] <= 7} {
        set stack(x) "$stack(x)e+0"
      }
    }
  }
  set status(liftlock) 0

}

# ------------------------------------------------------------------------------
proc func_sqrt {} {

  global FLAG stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x u
    csqrt
    move u x
  } else {
    set stack(x) [expr {sqrt($stack(x))}]
  }

}

# ------------------------------------------------------------------------------
proc func_xpow2 {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set istack(x) [expr {2.0*$stack(s)*$istack(s)}]
    set stack(x) [expr {1.0*$stack(s)*$stack(s) - $istack(s)*$istack(s)}]
  } else {
    set stack(x) [expr {pow($stack(x), 2)}]
  }

}

# ------------------------------------------------------------------------------
proc func_exp {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set istack(x) [expr {exp($stack(s))*sin($istack(s))}]
    set stack(x) [expr {exp($stack(s))*cos($istack(s))}]
  } else {
    set stack(x) [expr {exp($stack(x))}]
  }

}

# Two number complex helper functions operate on stack registers u and m
# ------------------------------------------------------------------------------
# cmul complex multiply, if U means stack(u), istack(u), then:  U = M * U
proc cmul {} {

  global stack istack

  set tmp $stack(u)

  set stack(u) [expr {(($stack(u) * $stack(m)) - ($istack(u) * $istack(m)))}]
  set istack(u) [expr {(($tmp * $istack(m)) + ($istack(u) * $stack(m)))}]

}

# ------------------------------------------------------------------------------
# cdiv complex divide, if U means stack(u), istack(u), then :  U = M / U
proc cdiv {} {

  global stack istack

  set tmp $stack(u)
  set divi [expr {1.0*$stack(u)*$stack(u) + $istack(u)*$istack(u)}]
  set stack(u) [expr {($stack(u)*$stack(m) + $istack(u)*$istack(m))/$divi}]
  set istack(u) [expr {($tmp*$istack(m) - $stack(m)*$istack(u))/$divi}]

}

# One number complex helper functions. They operate on stack register u.
# ------------------------------------------------------------------------------
proc cabs {} {

  global stack istack

  return [expr {sqrt(1.0*$stack(u)*$stack(u) + 1.0*$istack(u)*$istack(u))}]

}

# ------------------------------------------------------------------------------
proc cphi {} {

  global stack istack

  return [expr {atan2($istack(u), $stack(u))}]

}

# ------------------------------------------------------------------------------
proc csqrt {} {

  global stack istack

  set tmp $stack(u)
  set xb [cabs]
  set stack(u) [expr {sqrt(($stack(u) + $xb)/2.0)}]
  set istack(u) [expr {($istack(u) < 0 ? -1.0 : 1.0)*sqrt((-$tmp + $xb)/2.0)}]

}

# ------------------------------------------------------------------------------
proc cln {} {

  global stack istack

  set l [expr [cabs]]
  set istack(u) [expr [cphi]]
  set stack(u) [expr {log($l)}]

}

# ------------------------------------------------------------------------------
proc func_ln {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    if {$stack(x) == 0.0 && $istack(x) == 0.0} { error "" "" {ARITH INVALID} }
    move x u
    cln
    move u x
  } else {
    if {$stack(x) == 0.0} { error "" "" {ARITH INVALID} }
    set stack(x) [expr {log($stack(x))}]
  }

}

# ------------------------------------------------------------------------------
proc func_10powx {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set istack(x) [expr {pow(10.0,$stack(s))*sin($istack(s)*log(10.0))}]
    set stack(x) [expr {pow(10.0,$stack(s))*cos($istack(s)*log(10.0))}]
  } else {
    set stack(x) [expr {pow(10.0, $stack(x))}]
  }

}

# ------------------------------------------------------------------------------
proc func_log10 {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    if {$stack(x) == 0.0 && $istack(x) == 0.0} { error "" "" {ARITH INVALID} }
    move x u
    cln
    set istack(x) [expr {$istack(u)/log(10.0)}]
    set stack(x) [expr {$stack(u)/log(10.0)}]
  } else {
    if {$stack(x) == 0.0} { error "" "" {ARITH INVALID} }
    set stack(x) [expr {log10($stack(x))}]
  }

}

# ------------------------------------------------------------------------------
proc func_ypowx {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }

  if {$FLAG(8)} {
    if {$stack(x) <= 0.0 && $stack(y) == 0.0 && $istack(y) == 0.0} {
      error "" "" {ARITH INVALID}
    }
    move y u
    set stack(y) [expr {pow([cabs], $stack(x))*exp(-$istack(x)*[cphi])}]
    set istack(y) [expr {$stack(x)*[cphi] + $istack(x)*log([cabs])}]
    set lx $stack(y)
    set stack(y) [expr {cos($istack(y))*$stack(y)}]
    set istack(y) [expr {sin($istack(y))*$lx}]
    drop
  } else {
    if {$stack(x) <= 0.0 && $stack(y) == 0.0} { error "" "" {ARITH INVALID} }
    set stack(y) [expr {pow($stack(y), $stack(x))}]
    drop
  }

}

# ------------------------------------------------------------------------------
proc func_percent {} {

  global stack

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }

  set stack(x) [expr {($stack(y)/100.0) * $stack(x)}]

}

# ------------------------------------------------------------------------------
proc func_inv {} {

  global status FLAG stack istack MAT

  if {[isDescriptor $stack(x)]} {
    if {[::matrix::Rows $MAT($stack(x))] != [::matrix::Cols $MAT($stack(x))]} {
      error "" "" {DIMMAT}
    }

    set mID [::matrix::mkIdentity [::matrix::Rows $MAT($stack(x))]]
    chk_matmem $status(result) $stack(x)
    if {[catch {
      if {[isLU $stack(x)]} {
        set pivot $MAT($stack(x)\_LU)
      } else {
        set pivot {}
      }
      SETMAT $status(result) [::matrix::solvePGauss $MAT($stack(x)) $mID $pivot]}]
    } {
      error "" "" {ARITH INVALID}
    }
    set stack(x) $status(result)

  } elseif {$FLAG(8)} {
    if {$stack(x) == 0.0 && $istack(x) == 0.0} { error "" "" {ARITH INVALID} }
    move x s
    move x u
    set xb [expr pow([cabs],2)]
    set istack(x) [expr {-$istack(s)/$xb}]
    set stack(x) [expr {$stack(s)/$xb}]
  } else {
    if {$stack(x) == 0.0} { error "" "" {ARITH INVALID} }
    set stack(x) [expr {1.0/$stack(x)}]
  }

}

# ------------------------------------------------------------------------------
proc func_dpercent {} {

  global stack

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }
  if {$stack(y) == 0.0} { error "" "" {ARITH INVALID} }

  set stack(x) [expr {($stack(x)-$stack(y))/($stack(y)/100.0)}]

}

# ------------------------------------------------------------------------------
proc func_dsp_mode { mode param } {

  global status storage

  if {$param eq "I"} {
    if {[isDescriptor $storage(I)]} { error "" "" {MATRIX} }

    if {$storage(I) < 0} {
      set param 0
    } else {
      set param [expr int($storage(I)) > 9 ? 9 : int($storage(I))]
    }
  }

  if {$status(liftlock) > 0} {set status(liftlock) 2}
  set status(dispmode) $mode
  set status(dispprec) $param

}

# ------------------------------------------------------------------------------
proc lookup_label { lbl } {

  global prgstat PRGM

  if {$lbl < 0} {
    set target "42_21_1[expr abs($lbl)]"
  } elseif {$lbl > 9} {
    set target "42_21_48_[expr int($lbl - 10)]"
  } else {
    set target "42_21_$lbl"
  }

  set tl -1
  set wrap 0
  set ll [expr $prgstat(curline)+1]
  set plen [llength $PRGM]
  while {!$wrap} {
    if {$ll > $plen} {set ll 0}
    if {[lindex $PRGM $ll] == $target} {
      set tl $ll
      break
    } elseif {$ll == $prgstat(curline)} {
      set wrap 1
    }
    incr ll
  }

  return $tl

}

# ------------------------------------------------------------------------------
proc func_label { lbl } {

  global prgstat

  if {!$prgstat(running)} { show_x }

}

# ------------------------------------------------------------------------------
proc func_sst {} {

  global status prgstat PRGM KBD keyseq

  if {$status(PRGM)} {
    if {$KBD(state) == 0} {
      prgm_incr 1
      show_curline
    }
    if {$status(liftlock) > 0} {set status(liftlock) 3}
  } else {
    if {$KBD(state) == 0} {
      if {$prgstat(curline) == 0 && [llength $PRGM] > 1} {incr prgstat(curline)}
      show_curline
      seq_pending true
    } else {
      seq_pending false
      set prgstat(running) 1
      set keyseq ""
      prgm_step
      set prgstat(running) 0
      if {!$status(error)} { show_x }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_bst {} {

  global status prgstat PRGM KBD ShowX

  if {$KBD(state) == 0} {
    if {$prgstat(curline) > 0} {
      incr prgstat(curline) -1
    } else {
      set prgstat(curline) [expr [llength $PRGM] - 1]
    }
  }

  if {!$status(PRGM)} {
    if {$KBD(state) == 0} {
      set status(num) 1
      show_curline
      set ShowX 0
      seq_pending true
    } else {
      set ShowX 1
      seq_pending false
    }
  }

}

# ------------------------------------------------------------------------------
proc func_gto_chs { trigger } {

  global status

  if {!$status(error)} {show_prgm $trigger}

}

# ------------------------------------------------------------------------------
proc func_gto { lbl } {

  global storage prgstat PRGM

  if {$lbl eq "I"} {
    if {[isDescriptor $storage(I)]} {
      set lbl [expr 19+[string index $storage(I) 1]]
    } else {
      set lbl [expr int($storage(I))]
    }

    if {$lbl < 0 && abs($lbl) < [llength $PRGM]} {
      set ll [expr abs($lbl)]
    } elseif {$lbl >= 0 && $lbl <= 19} {
      set ll [lookup_label $lbl]
    } elseif {$lbl >= 20 && $lbl <= 24} {
      set ll [lookup_label [expr {19-$lbl}]]
    } else {
      set ll -1
    }
  } else {
    set ll [lookup_label $lbl]
  }

  if {$ll == -1} { error "" "" {ADDRESS} }
  set prgstat(curline) $ll

}

# ------------------------------------------------------------------------------
proc func_gsb { lbl } {

  global HP15 storage prgstat PRGM

  if {$lbl eq "I"} {
    if {[isDescriptor $storage(I)]} {
      set lbl [expr 19+[string index $storage(I) 1]]
    } else {
      set lbl [expr int($storage(I))]
    }

    if {$lbl < 0 && abs($lbl) < [llength $PRGM]} {
      set ll [expr {abs($lbl)}]
    } elseif {$lbl >= 0 && $lbl <= 19} {
      set ll [lookup_label $lbl]
    } elseif {$lbl >= 20 && $lbl <= 24} {
      set ll [lookup_label [expr {19-$lbl}]]
    } else {
      set ll -1
    }
  } else {
    set ll [lookup_label $lbl]
  }

  if {$ll == -1} { error "" "" {ADDRESS} }
  if {$prgstat(running)} {
    if {[llength $prgstat(rtnadr)] < $HP15(gsbmax)} {
      prgm_addrtn [expr {$prgstat(curline)+1}]
      set prgstat(curline) $ll
    } else {
      error "" "" {RTN}
    }
  } else {
    set prgstat(rtnadr) {}
    prgm_run $ll
  }

}

# ------------------------------------------------------------------------------
proc func_matrix { fn } {

  global status prgstat FLAG stack storage MAT

  if {![isDescriptor $stack(x)] && $fn in {2 3 4 5 6 9} } {
    error "" "" {DIMMAT}
  }

  switch $fn {
    0 {
      move LSTx s
      matrix_init
    }
    1 {
      move LSTx s
      set storage(0) 1
      set storage(1) 1
    }
    2 {
# ZP -> Z~
      if {[::matrix::Rows $MAT($stack(x))] % 2 != 0} { error "" "" {DIMMAT} }
      if {[::matrix::Rows $MAT($stack(x))]*2*[::matrix::Cols $MAT($stack(x))] > 64} {
        error "" "" {DIM}
      }

      move LSTx s
      chk_matmem $stack(x) \
        [expr [::matrix::Rows $MAT($stack(x))]*[::matrix::Cols $MAT($stack(x))]*2]
      SETMAT $stack(x) [::matrix::ZPtoZtilde $MAT($stack(x))]
    }
    3 {
# Z~ -> ZP
      if {[::matrix::Cols $MAT($stack(x))] % 2 != 0} { error "" "" {DIMMAT} }

      move LSTx s
      SETMAT $stack(x) [::matrix::ZtildetoZP $MAT($stack(x))]
    }
    4 {
# Transpose
      move LSTx s
      SETMAT $stack(x) [::matrix::Transpose $MAT($stack(x))]
    }
    5 {
# A^T x B
      if {($status(result) == $stack(x) || $status(result) == $stack(y)) ||
          ![isDescriptor $stack(y)]} {
        error "" "" {DIMMAT}
      }
      set AT [::matrix::Transpose $MAT($stack(y))]
      if {![::matrix::Conforming matmul $AT $MAT($stack(x))]} {
        error "" "" {DIMMAT}
      }

      chk_matmem $status(result) \
        [expr [::matrix::Rows $AT]*[::matrix::Cols $MAT($stack(x))]]
      SETMAT $status(result) [::matrix::Multiply $AT $MAT($stack(x))]
      if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
      set stack(y) $status(result)
      drop
    }
    6 {
# Residual: R-YX; rYxcX - rYxcY * rXxcX
      if {![isDescriptor $stack(y)] ||
      ($status(result) == $stack(x) || $status(result) == $stack(y)) ||
          ![::matrix::Conforming matmul $MAT($stack(y)) $MAT($stack(x))] ||
          [::matrix::Rows $MAT($stack(y))] != [::matrix::Rows $MAT($status(result))] ||
          [::matrix::Cols $MAT($stack(x))] != [::matrix::Cols $MAT($status(result))]
        } {
        error "" "" {DIMMAT}
      }

      SETMAT $status(result) [::matrix::Sub $MAT($status(result)) \
        [::matrix::Multiply $MAT($stack(y)) $MAT($stack(x))]]
      if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
      set stack(y) $status(result)
      drop
    }
    7 {
# Row norm
      if {[isDescriptor $stack(x)]} {
        set stack(x) [::matrix::RowNorm $MAT($stack(x))]
      } else {
        prgm_incr [expr {$prgstat(running) ? 2 : 1}]
      }
    }
    8 {
# Euclidean norm
      if {[isDescriptor $stack(x)]} {
        set stack(x) [::matrix::EuclideanNorm $MAT($stack(x))]
      } else {
        set stack(x) [expr {abs($stack(x))}]
        prgm_incr [expr {$prgstat(running) ? 2 : 1}]
      }
    }
    9 {
# Determinante
      if {[::matrix::Rows $MAT($stack(x))] != [::matrix::Cols $MAT($stack(x))]} {
        error "" "" {DIMMAT}
      }

      chk_matmem $status(result) $stack(x)
# Result matrix will contain LU form
      set LU $MAT($stack(x))
      if {[isLU $stack(x)]} {
        set pivot $MAT($stack(x)\_LU)
      } else {
        set pivot [::matrix::dgetrf LU]
      }
      set det [::matrix::Det $LU $pivot]
      set stack(x) [lindex $det 0]
      SETMAT $status(result) $LU $pivot
    }
  }
  show_x

}

# ------------------------------------------------------------------------------
proc func_dim_matrix { idx } {

  global stack MAT

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }

  set md [Descriptor $idx]
  set rr [expr int(abs($stack(y)))]
  set cc [expr int(abs($stack(x)))]
  if {$rr*$cc > 64} { error "" "" {DIM} }

  chk_matmem $md [expr {$rr*$cc}]
# Reset LU status if shape changes
  if {$rr != [::matrix::Rows $MAT($md)] || $cc != [::matrix::Cols $MAT($md)]} {
    set MAT($md\_LU) {}
  }
  SETMAT $md [::matrix::Dim $MAT($md) $rr $cc] $MAT($md\_LU)
  mem_recalc

}

# ------------------------------------------------------------------------------
proc func_result { idx } {

  global status

  set status(result) [Descriptor $idx]

}

# ------------------------------------------------------------------------------
proc func_sto_result {} {

  global status stack

  if {![isDescriptor $stack(x)]} { error "" "" {DIMMAT} }

  set status(result) $stack(x)

}

# ------------------------------------------------------------------------------
proc func_rcl_result {} {

  global status stack

  if {!$status(liftlock)} {lift}
  set stack(x) $status(result)

}

# ------------------------------------------------------------------------------
proc func_hyp { func } {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    switch $func {
      sin {
        set istack(x) [expr {cosh($stack(s))*sin($istack(s))}]
        set stack(x) [expr {sinh($stack(s))*cos($istack(s))}]
      }
      cos {
        set istack(x) [expr {sinh($stack(s))*sin($istack(s))}]
        set stack(x) [expr {cosh($stack(s))*cos($istack(s))}]
      }
      tan {
        set divi [expr {(cosh(2.0*$stack(s)) + cos(2.0*$istack(s)))}]
        set istack(x) [expr {sin(2.0*$istack(s))/$divi}]
        set stack(x) [expr {sinh(2.0*$stack(s))/$divi}]
      }
    }
  } else {
    set stack(x) [expr $func\h($stack(x))]
  }

}

# ------------------------------------------------------------------------------
proc func_ahyp { func } {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    switch $func {
      sin {
        set stack(u) [expr {1.0 + $istack(s)}]
        set istack(u) [expr {-$stack(s)}]
        csqrt
        move u m
        set stack(u) [expr {1.0 - $istack(s)}]
        set istack(u) $stack(s)
        csqrt
        set istack(x) \
          [expr {atan2($istack(s),(($stack(m)*$stack(u))-($istack(m)*$istack(u))))}]
        set tmp [expr {($stack(m)*$istack(u))-($stack(u)*$istack(m))}]
        set st [expr $tmp < 0.0 ? -1.0 : 1.0]
        set stack(x) [expr {$st * log(abs($tmp) + sqrt(($tmp*$tmp)+1.0))}]
      }
      cos {
        set stack(u) [expr {$stack(s) - 1.0}]
        set istack(u) $istack(s)
        csqrt
        move u m
        set stack(u) [expr {$stack(s) + 1.0}]
        set istack(u) $istack(s)
        csqrt
        set istack(x) [expr {2.0 * atan2($istack(m),$stack(u))}]
        set tmp [expr {($stack(m)*$stack(u))+($istack(m)*$istack(u))}]
        set st [expr {$tmp < 0.0 ? -1.0 : 1.0}]
        set stack(x) [expr {$st * log(abs($tmp) + sqrt(($tmp*$tmp)+1.0))}]
      }
      tan {
        if {$istack(x) == 0.0 && $stack(x) == 1.0} {
          set istack(x) 0.0
          error "" "" {ARITH OVERFLOW}
        }
        if {$istack(x) == 0.0 && $stack(x) == -1.0} {
          set istack(x) 0.0
          error "" "" {ARITH NOVERFLOW}
        }
        set stack(m) [expr {1.0 + $stack(s)}]
        set istack(m) $istack(s)
        set stack(u) [expr {1.0 - $stack(s)}]
        set istack(u) [expr {-$istack(s)}]
        cdiv
        cln
        set stack(m) 0.5
        set istack(m) 0.0
        cmul
        if {$istack(x) == 0.0 && $stack(x) > 1.0} {
          set istack(u) [expr {-$istack(u)}]
        }
        move u x
      }
    }
  } else {
    switch $func {
      sin {
        set sx [expr {$stack(x) < 0.0 ? -1.0 : 1.0}]
        set stack(x) \
          [expr {$sx * log(abs($stack(x)) + sqrt($stack(x)*$stack(x) + 1.0))}]
      }
      cos {
        set stack(x) [expr {log($stack(x) + sqrt($stack(x)*$stack(x) - 1.0))}]
      }
      tan {
        if {abs($stack(x)) > 1.0} { error "" "" {ARITH INVALID} }
        set stack(x) [expr {log(sqrt((1.0 + $stack(x)) / (1.0 - $stack(x))))}]
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_sin {} {

  global status FLAG stack istack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set istack(x) [expr {cos($stack(s))*sinh($istack(s))}]
    set stack(x) [expr {sin($stack(s))*cosh($istack(s))}]
  } else {
    set xx [expr {$stack(x)/$status(rangle)}]
    set xx [expr {$xx - (floor($xx/2.0)*2.0)}]
    switch $xx {
      0.0 {set stack(x)  0.0}
      0.25 {set stack(x) [expr sqrt(0.5)]}
      0.5 {set stack(x)  1.0}
      0.75 {set stack(x) [expr sqrt(0.5)]}
      1.0 {set stack(x)  0.0}
      1.25 {set stack(x) [expr -sqrt(0.5)]}
      1.5 {set stack(x) -1.0}
      1.75 {set stack(x) [expr -sqrt(0.5)]}
      default {set stack(x) [expr {sin($stack(x)/$status(rangle)*$PI)}]}
    }
  }

}

# ------------------------------------------------------------------------------
proc func_cos {} {

  global status FLAG stack istack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set istack(x) [expr {-sin($stack(s))*sinh($istack(s))}]
    set stack(x) [expr {cos($stack(s))*cosh($istack(s))}]
  } else {
    set xx [expr {$stack(x)/$status(rangle)}]
    set xx [expr {$xx - (floor($xx/2.0)*2.0)}]
    switch $xx {
      0.0 {set stack(x)  1.0}
      0.25 {set stack(x) [expr sqrt(0.5)]}
      0.5 {set stack(x)  0.0}
      0.75 {set stack(x) [expr -sqrt(0.5)]}
      1.0 {set stack(x) -1.0}
      1.25 {set stack(x) [expr -sqrt(0.5)]}
      1.5 {set stack(x)  0.0}
      1.75 {set stack(x) [expr sqrt(0.5)]}
      default {set stack(x) [expr {cos($stack(x)/$status(rangle)*$PI)}]}
    }
  }

}

# ------------------------------------------------------------------------------
proc func_tan {} {

  global status FLAG stack istack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    set divi [expr {cos(2.0*$stack(x))+cosh(2.0*$istack(x))}]
    set istack(x) [expr {sinh(2.0*$istack(s))/$divi}]
    set stack(x) [expr {sin(2.0*$stack(s))/$divi}]
  } else {
    set xx [expr {$stack(x)/$status(rangle)}]
    set xx [expr {$xx - (floor($xx/2.0)*2.0)}]
    switch $xx {
      0.0  {set stack(x)  0.0}
      0.25 {set stack(x)  1.0}
      0.5  {error "" "" {ARITH OVERFLOW}}
      0.75 {set stack(x) -1.0}
      1.0  {set stack(x)  0.0}
      1.25 {set stack(x)  1.0}
      1.5  {error "" "" {ARITH OVERFLOW}}
      1.75 {set stack(x) -1.0}
      default {set stack(x) [expr {tan($stack(x)/$status(rangle)*$PI)}]}
    }
  }

}

# ------------------------------------------------------------------------------
proc func_atrign { func } {

  global status FLAG stack istack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x s
    switch $func {
      sin {
       set stack(u) [expr {1.0 + $stack(s)}]
       set istack(u) $istack(s)
       csqrt
       move u m
       set stack(u) [expr {1.0 - $stack(s)}]
       set istack(u) [expr {-$istack(s)}]
       csqrt
       set tmp [expr {($stack(m)*$istack(u))-($stack(u)*$istack(m))}]
       set st [expr {$tmp < 0.0 ? -1.0 : 1.0}]
       set istack(x) [expr {-($st * log(abs($tmp)+sqrt(($tmp*$tmp)+1.0)))}]
       set stack(x) \
         [expr {atan2($stack(s),($stack(m)*$stack(u))-($istack(m)*$istack(u)))}]
      }
      cos {
       set stack(u) [expr {1.0 - $stack(s)}]
       set istack(u) [expr {-$istack(s)}]
       csqrt
       move u m
       set stack(u) [expr {1.0 + $stack(s)}]
       set istack(u) $istack(s)
       csqrt
       set tmp [expr {($stack(u)*$istack(m))-($istack(u)*$stack(m))}]
       set st [expr {$tmp < 0.0 ? -1.0 : 1.0}]
       set istack(x) [expr {$st * log(abs($tmp)+sqrt(($tmp*$tmp)+1.0))}]
       set stack(x) [expr {2.0 * atan2($stack(m),$stack(u))}]
      }
      tan {
        if {$stack(s) == 0.0 && $istack(s) == 1.0} {
          set stack(x) 0.0
          error "" "" {ARITH IOVERFLOW}
        }
        if {$stack(s) == 0.0 && $istack(s) == -1.0} {
          set stack(x) 0.0
          error "" "" {ARITH INOVERFLOW}
        }
        set stack(m) $stack(s)
        set istack(m) [expr {1.0 + $istack(s)}]
        set stack(u) [expr {-$stack(s)}]
        set istack(u) [expr {1.0 - $istack(s)}]
        cdiv
        cln
        set stack(m) 0.0
        set istack(m) 0.5
        cmul
        if {$stack(s) == 0.0 && abs($istack(s)) > 1.0} {
          set stack(u) [expr {-$stack(u)}]
        }
        move u x
      }
    }
  } else {
    set stack(x) [expr a$func\($stack(x))/$PI*$status(rangle)]
  }

}

# ------------------------------------------------------------------------------
proc func_dim_mem {} {

  global HP15 stack storage

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set rr [expr abs(int($stack(x)))]
  if {$rr < 1} {set rr 1}
  if {$rr > $HP15(dataregs) + $HP15(poolregsfree)} { error "" "" {DIM} }

  for {set ii [expr $rr+1]} {$ii <= $HP15(totregs)} {incr ii} {
    array unset storage $ii
  }
  for {set ii [expr $HP15(dataregs)+1]} {$ii <= $rr} {incr ii} {
    set storage($ii) 0.0
  }
  set HP15(dataregs) $rr
  mem_recalc

}

# ------------------------------------------------------------------------------
proc func_i {} {

  global HP15 status FLAG stack istack curdisp ShowX KBD

  if {!$status(PRGM)} {
    if {$FLAG(8)} {
      if {$KBD(state) == 0 && [seq_pending] eq ""} {
        if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

        set curdisp [format_number $istack(x)]
        seq_pending true
        set ShowX 0
      } else {
        if {$KBD(wait) == 0} {
          set KBD(wait) 1
          while {$KBD(wait) > 0} {
            after $HP15(pause) "set KBD(release) 0"
            tkwait variable KBD(release)
            incr KBD(wait) -1
          }
          seq_pending false
          set ShowX 1
          set KBD(wait) 0
        } elseif {$KBD(wait) == 1} {
          set KBD(wait) 2
        }
      }
    } elseif {$KBD(state) == 0} {
      error "" "" {INDEX}
    }
  }

}

# ------------------------------------------------------------------------------
proc func_I {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {!$FLAG(8)} {func_sf 8}
  set istack(y) [expr {$stack(x)*1.0}]
  drop

}

# ------------------------------------------------------------------------------
proc func_pi {} {

  global status stack istack PI

  if {!$status(liftlock)} {lift}
  set stack(x) $PI
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_sf { flag } {

  global HP15 FLAG storage

  if {$flag eq "I"} {
    if {[isDescriptor $storage(I)]} { error "" "" {MATRIX} }

    set flag [expr int(abs($storage(I)))]
  }
  if {$flag < 0 || $flag > 9} { error "" "" {FLAG} }

  if {$flag == 8} {
    if {$HP15(poolregsfree) < 5} { error "" "" {DIM} }
    trace add variable ::istack(x) write chk_range
    trace add variable ::istack(y) write chk_range
    mem_recalc
  }
  set FLAG($flag) 1
  set_status NIL

}

# ------------------------------------------------------------------------------
proc func_cf { flag } {

  global FLAG istack storage

  if {$flag eq "I"} {
    if {[isDescriptor $storage(I)]} { error "" "" {MATRIX} }

    set flag [expr int(abs($storage(I)))]
  }
  if {$flag < 0 || $flag > 9} { error "" "" {FLAG} }

  if {$flag == 8} {
    trace remove variable ::istack(x) write chk_range
    trace remove variable ::istack(y) write chk_range
    foreach ii [array names istack] {
      set istack($ii) 0.0
    }
    mem_recalc
  }
  set FLAG($flag) 0
  if {$flag == 9} { set ::matrix::OVERFLOW 0 }
  set_status NIL

}

# ------------------------------------------------------------------------------
proc func_Finq { flag } {

  global prgstat FLAG storage

  if {$flag eq "I"} {
    if {[isDescriptor $storage(I)]} { error "" "" {MATRIX} }

    set flag [expr int($storage(I))]
  }
  if {$flag < 0 || $flag > 9} { error "" "" {FLAG} }

  if {$prgstat(running)} {
    set ii [expr $FLAG($flag) ? 1 : 2]
  } else {
    set ii [expr $FLAG($flag) ? 0 : 1]
  }
  prgm_incr $ii

}

# ------------------------------------------------------------------------------
proc func_clearsumregs {} {

  global HP15 stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }

  for {set ii 2} {$ii < 8} {incr ii} {
    set storage($ii) 0.0
  }
  foreach ii {x y z t} {
    set stack($ii) 0.0
    set istack($ii) 0.0
  }

}

# ------------------------------------------------------------------------------
proc func_roll { cnt } {

  global status

# WA-MAC: Block stack roll while popup menu is shown under macOS
  if {![winfo exists .popup]} {
    set status(num) 1
    for {set ii 0} {$ii < $cnt} {incr ii} {
      foreach jj {stack istack} {
        upvar #0 $jj st

        set tmp   $st(y)
        set st(y) $st(z)
        set st(z) $st(t)
        set st(t) $st(x)
        set st(x) $tmp
      }
    }
    show_x
  }

}

# ------------------------------------------------------------------------------
proc func_chs {} {

  global status stack MAT

  if {[isDescriptor $stack(x)]} {
    SETMAT $stack(x) [::matrix::CHS $MAT($stack(x))]
  } elseif {$status(num)} {
    if {$stack(x) == 0.0} {
      set status(liftlock) 2
    } else {
      set stack(x) [expr {-$stack(x)}]
    }
  } else {
    if {[string first "e" $stack(x)] > 0} {
      set stack(x) [string map {e+ e- e- e+} $stack(x)]
    } elseif {$stack(x) != 0.0} {
      if {[string index $stack(x) 0] eq "-"} {
        set stack(x) [string range $stack(x) 1 end]
      } else {
        set stack(x) "-$stack(x)"
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_abs {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$FLAG(8)} {
    move x u
    set istack(x) 0.0
    set stack(x) [cabs]
  } else {
    set stack(x) [expr {abs($stack(x))}]
  }

}

# ------------------------------------------------------------------------------
proc func_xexchg { param } {

  global stack storage MAT

  move x s
  set param [GETREG $param]
  if {[isDescriptor $param]} {
    if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

    lassign [matrix_getRowCol $param regs] row col
    set stack(x) [::matrix::GetElem $MAT($param) $row $col]
    ::matrix::SetElem MAT($param) $row $col [expr {$stack(s)*1.0}]
  } else {
    set stack(x) $storage($param)
    if {[isDescriptor $stack(s)]} {
      set storage($param) $stack(s)
    } else {
      set storage($param) [expr {$stack(s)*1.0}]
    }
  }

}

# ------------------------------------------------------------------------------
proc func_dse { param } {

  global storage MAT prgstat

  set param [GETREG $param]
  set mm [isDescriptor $param]
  if {$mm} {
    lassign [matrix_getRowCol $param regs] row col
    set val [::matrix::GetElem $MAT($param) $row $col]
  } else {
    if {[isDescriptor $storage($param)]} { error "" "" {MATRIX} }

    set val $storage($param)
  }

  set nn [expr int($val)]
  set yy [expr {round(abs(($val - $nn)*1E5))}]
  set xx [expr {int($yy/100.0)}]
  set yy [expr {round($yy - $xx*100.0)}]
  set nn [expr $nn-($yy == 0.0 ? 1 : $yy)]
  if {$nn <= $xx} {
    prgm_incr [expr {$prgstat(running) ? 2 : 1}]
  }

  set val "$nn.[format "%03d%02d" $xx $yy]"
  if {$mm} {
    ::matrix::SetElem MAT($param) $row $col $val
  } else {
    set storage($param) $val
  }

}

# ------------------------------------------------------------------------------
proc func_isg { param } {

  global storage MAT prgstat

  set param [GETREG $param]
  set mm [isDescriptor $param]
  if {$mm} {
    lassign [matrix_getRowCol $param regs] row col
    set val [::matrix::GetElem $MAT($param) $row $col]
  } else {
    if {[isDescriptor $storage($param)]} { error "" "" {MATRIX} }

    set val $storage($param)
  }

  set nn [expr {int($val)}]
  set yy [expr {round(abs(($val - $nn)*1E5))}]
  set xx [expr {int($yy/100.0)}]
  set yy [expr {round($yy - $xx*100.0)}]
  set nn [expr {$nn+($yy == 0.0 ? 1 : $yy)}]
  if {$nn > $xx} {
    prgm_incr [expr {$prgstat(running) ? 2 : 1}]
  }

  set val "$nn.[format "%03d%02d" $xx $yy]"
  if {$mm} {
    ::matrix::SetElem MAT($param) $row $col $val
  } else {
    set storage($param) $val
  }

}

# ------------------------------------------------------------------------------
# Optimisation 1:
# If the calculated secant is nearly horizontal, SOLVE modifies the secant
# method to ensure that |c - b| <= 100 |a - b|.
#
# Optimisation 2:
# If SOLVE has already found values x0 and x1 such that f(x0) and f(x1) have
# opposite signs, it modifies the secant method to ensure that x2 always lies
# within the interval containing the sign change.
#
# Optimisation 3:
# If SOLVE hasn't found a sign change and a sample value x2 doesn't yield a
# function value with diminished magnitude, then SOLVE fits a parabola through
# the function values at x0, x1, and x2. SOLVE finds the value x3 at which the
# parabola has its maximum or minimum, relabels x3 as x0, and then continues the
# search using the secant method.

proc secant { ll } {

  global HP15 status stack prgstat

  set x0 $stack(y)
  set x1 $stack(x)
  if {$HP15(strictHP15)} {
    set ebs 1e-8
  } else {
    set ebs 1e-14
  }
  set cntmax 25
  set ii 2
  set x2 0.0
  set chs 0
  set rc 0

# From page 192 of the HP-15C Owner's Handbook
  if {$x0 == $x1} {
    set x1 [expr {$x1 + 1e-7}]
  }

  populate $x0
  prgm_addrtn 0
  prgm_run $ll
  set f_x0 $stack(x)

  populate $x1
  prgm_addrtn 0
  prgm_run $ll
  set f_x1 $stack(x)

  while {!$prgstat(interrupt)} {

    if {$f_x1-$f_x0 != 0.0} {
      set slope [expr {($x1-$x0)/($f_x1-$f_x0)}]
      set slope [expr {abs($slope) > 10 ? $slope*2.0 : $slope}]
    } else {
      if {$f_x0 < 0} {
        set slope -0.5001
      } else  {
        set slope 0.5001
      }
    }
    set x2 [expr {$x1 - $f_x1*$slope}]

# Optimisation 1
    if {abs($x2-$x1) > 100.0*abs($x0-$x1)} {
      set x2 [expr {$x1-100.0*($x0-$x1)}]
    }

# Optimisation 2
    if {$f_x0*$f_x1 < 0 && ($x2 < min($x0, $x1) || $x2 > max($x0, $x1))} {
      set x2 [expr {($x0+$x1)/2.0}]
    }

    populate $x2
    prgm_addrtn 0
    prgm_run $ll
    set f_x2 $stack(x)

    set x0 $x1
    set f_x0 $f_x1
    set x1 $x2
    set f_x1 $f_x2

    if {$f_x0*$f_x1 < 0} {
      set chs 1
    }
    incr ii

# Root found or abort?
    if {(abs($f_x2) < $ebs) || ($f_x0*$f_x1 < 0.0 && abs(abs($x0)-abs($x1)) < $ebs)} {
      set rc 1
      break
    } elseif {$ii > $cntmax} {
      set rc $chs
      break
    }
  }

  if {!$status(error)} {
    set stack(z) $f_x1
    set stack(y) $x1
    set stack(x) $x2
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc func_solve { lbl } {

  global HP15 status prgstat

  if {$status(solve)} {error "" "" {RECURSION}}

  set status(solve) 0
  set ll [lookup_label $lbl]

  if {$HP15(poolregsfree) < 5} { error "" "" {DIM} }
  if {$ll == -1} { error "" "" {ADDRESS} }
  if {$prgstat(running) && [llength $prgstat(rtnadr)] > 5} { error "" "" {RTN} }

  set status(solve) 1
  prgm_addrtn $prgstat(curline)

  try {
    set rf [secant $ll]
  } trap {INTERRUPT} {} {
    if {!$status(integrate)} { set prgstat(interrupt) 0 }
    prgm_purgertn
    set rf 0
  }

  func_rtn
  set status(solve) 0
  set status(num) 1

  if {$rf == 0} {
    if {$prgstat(running)} {
      prgm_incr 2
    } else {
      error_handler { SOLVE }
    }
  }

}

# ------------------------------------------------------------------------------
proc romberg_eval { ll xx } {

  global stack

  populate $xx
  prgm_addrtn 0
  prgm_run $ll

  return $stack(x)

}

# ------------------------------------------------------------------------------
proc romberg { lbl a b } {

  global status prgstat

  array set R {}

  set hh [expr {$b - $a}]
  lappend R(0) [expr {$hh/2.0*([romberg_eval $lbl $a] + [romberg_eval $lbl $b])}]

  set nmax 15
  for {set nn 1} {$nn <= $nmax && !$prgstat(interrupt)} {incr nn} {
    set Rmm $R([expr {$nn-1}])
    set hh [expr {$hh/2.0}]
    set sum 0.0
    for {set ii 1} {$ii <= (pow(2,$nn)-1)} {incr ii 2} {
      set xx [expr $a + $ii*$hh]
      set sum [expr $sum + [romberg_eval $lbl $xx]]
    }
    lappend R($nn) [expr 0.5*[lindex $Rmm 0] + $hh*$sum]

    set mm 1
    for {set jj 0} {$jj < $nn} {incr jj} {
      set mm [expr 4.0*$mm]
      lappend R($nn) [expr {[lindex $R($nn) $jj] + \
        (([lindex $R($nn) $jj] - [lindex $Rmm $jj])/($mm - 1))}]
    }

    regexp {.*e([+-][0-9]+)} [format {%e} [lindex $R($nn) end]] ign log
    regsub {([+-])0+([0-9]+)} $log {\1\2} log
    set ebs [expr pow(10, $log-$status(dispprec))]
    set delta [expr {abs([lindex $R($nn) end] - [lindex $Rmm end])}]
    if {$delta < $ebs || $status(error)} break;

  }

  return [list [lindex $R([expr {$nn-1}]) end] $delta]

}

# ------------------------------------------------------------------------------
proc func_integrate { lbl } {

  global HP15 status stack prgstat

  if {$status(integrate)} {error "" "" {RECURSION}}

  set status(integrate) 0
  set ll [lookup_label $lbl]

  if {$HP15(poolregsfree) < 23} { error "" "" {DIM} }
  if {$ll == -1} { error "" "" {ADDRESS} }
  if {$prgstat(running) && [llength $prgstat(rtnadr)] > 5} { error "" "" {RTN} }

  if {$stack(x) == $stack(y)} {
    set stack(t) $stack(y)
    set stack(z) $stack(x)
    set stack(y) 0.0
    set stack(x) 0.0
  } else {
    set status(integrate) 1
    prgm_addrtn $prgstat(curline)

    if {$stack(y) < $stack(x)} {
      set lb $stack(y)
      set ub $stack(x)
      set signresult 1.0
    } else {
      set lb $stack(x)
      set ub $stack(y)
      set signresult -1.0
    }

    try {
      lassign [romberg $ll $lb $ub] res relerr
    } trap {INTERRUPT} {} {
      if {!$status(solve)} { set prgstat(interrupt) 0 }
      prgm_purgertn
    }

    func_rtn
    set status(integrate) 0
    set status(num) 1

    if {!$status(error)} {
      if {[info exists res]} {
        if {$signresult == 1.0} {
          set stack(t) $lb
          set stack(z) $ub
        } else {
          set stack(t) $ub
          set stack(z) $lb
        }
        set stack(y) $relerr
        set stack(x) [expr {$res * $signresult}]
      } else {
        show_x
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_clearprgm {} {

  global HP15 status prgstat PRGM

  set prgstat(curline) 0
  set prgstat(interrupt) 0
  if {$status(PRGM)} {
    set HP15(prgmname) ""
    set prgstat(running) 0
    set prgstat(rtnadr) {}
    set PRGM {{}}
    array unset ::prdoc::DESC
    show_curline
    mem_recalc
  }

}

# ------------------------------------------------------------------------------
proc func_clearreg {} {

  global HP15 status storage

  for {set ii 0} {$ii <= $HP15(dataregs)} {incr ii} {
    set storage($ii) 0.0
  }
  set storage(I) 0.0
  if {$status(liftlock) > 0} {set status(liftlock) 2}

}

# ------------------------------------------------------------------------------
proc func_rnd {} {

  global status stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set stack(x) [format "%.$status(dispprec)f" $stack(x)]

}

# ------------------------------------------------------------------------------
proc func_xy {} {

  global FLAG stack istack

  move x s
  set stack(x) $stack(y)
  set stack(y) $stack(s)

  if {$FLAG(8)} {
    set istack(x) $istack(y)
    set istack(y) $istack(s)
  }

}

# ------------------------------------------------------------------------------
proc func_prefix {} {

  global HP15 status stack curdisp ShowX KBD

  if {!$status(PRGM)} {
    if {$KBD(state) == 0 && [seq_pending] eq ""} {
      seq_pending true
      if {[isDescriptor $stack(x)]} {
        show_matrix $stack(x) STACK dspbg
        key_release btn_35
      } else {
        regexp {( [0-9]{10})} [string map {. "" - " "} [format " %.10e" $stack(x)]] curdisp
      }
      set ShowX 0
    } else {
      if {$KBD(wait) == 0} {
        set KBD(wait) 1
        while {$KBD(wait) > 0} {
          after $HP15(pause) "set KBD(release) 0"
          tkwait variable KBD(release)
          incr KBD(wait) -1
        }
        seq_pending false
        set ShowX 1
        set KBD(wait) 0
      } elseif {$KBD(wait) == 1} {
        set KBD(wait) 2
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_bs {} {

  global status prgstat FLAG stack PRGM

  if {$status(PRGM)} {
    if {$prgstat(curline) > 0} {
      set PRGM [lreplace $PRGM $prgstat(curline) $prgstat(curline)]
      incr prgstat(curline) -1
      mem_recalc
      show_curline
    }
  } else {
    if {$FLAG(9)} {
      set FLAG(9) 0
    } elseif {$status(num) || [isDescriptor $stack(x)]} {
      set stack(x) 0.0
      set status(liftlock) 1
    } else {
      regsub {e[+-]0?$} $stack(x) "e" temp
      regsub {^-[0-9]$} $temp "" temp
      if {[string length $temp] > 1} {
        if {[regexp {e-0?$} $stack(x)]} {
          regsub {e-0?$} $stack(x) {e+0} stack(x)
        } elseif {[regexp {e-[1-9]$} $stack(x)]} {
          regsub {e-[1-9]$} $stack(x) {e-0} stack(x)
        } else {
          regsub {e[+-]$} [string range $temp 0 end-1] {e+0} stack(x)
        }
      } else {
        set status(liftlock) 1
        set status(num) 1
        set stack(x) 0.0
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc func_clx {} {

  global stack

  set stack(x) 0.0

}

# ------------------------------------------------------------------------------
proc clearall {} {

  global status

  if {!$status(PRGM)} {
    populate 0.0
    dispatch_key 42_34
    move x LSTx
    move x u
    move x m
    move x s
    set status(num) 1
  }

}

# ------------------------------------------------------------------------------
proc func_frac {} {

  global stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$stack(x) <= -1.0 || $stack(x) >= 1.0} {
    regexp {^([-+ ])?([0-9]+)(\.[0-9]+)*e?([+-][0-9]+)?} \
      [expr $stack(x)] all sign mint mfrac expo
    if {$mfrac eq "" || ($expo ne "" && abs($expo) > 8)} {
      set stack(x) 0.0
    } else {
      set stack(x) $sign$mfrac
    }
  }

}

# ------------------------------------------------------------------------------
proc func_sto { reg } {

  global HP15 stack storage

  if {$reg ne "I" && $reg > $HP15(dataregs)} { error "" "" {INDEX} }

  if {[isDescriptor $stack(x)]} {
    set storage($reg) $stack(x)
  } else {
    set storage($reg) [expr {$stack(x)*1.0}]
  }

}

# ------------------------------------------------------------------------------
proc func_sto_i { {user ""} } {

  global stack storage

  set param [GETREG "(i)"]
  if {[isDescriptor $param]} {
    if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

    func_sto_matrix regs $user [string index $param 1]
# Matrix in X-reg
  } elseif {[isDescriptor $stack(x)]} {
    set storage($param) $stack(x)
  } else {
    set storage($param) [expr {$stack(x)*1.0}]
  }

}

# ------------------------------------------------------------------------------
proc func_sto_matrix { mode {user ""} idx } {

  global HP15 status stack MAT prgstat curdisp ShowX KBD

  set md [Descriptor $idx]
  lassign [matrix_getRowCol $md $mode] row col
  if {$mode eq "regs"} {
    set val $stack(x)
  } else {
    set val $stack(z)
  }

  if {$KBD(state) == 0 && [seq_pending] eq ""} {
    set curdisp [format " %s%3s$status(dot)%s" [matrix_name $md] [expr $row+1] [expr $col+1]]
    if {$status(null) == -1} {
      set status(null) [after 3000 disp_null]
    }
    seq_pending true
    set ShowX 0
  } else {
    if {$KBD(wait) == 0} {
      if {!$prgstat(running)} {
        set KBD(wait) 1
        while {$KBD(wait) > 0} {
          after $HP15(pause) "set KBD(release) 0"
          tkwait variable KBD(release)
          incr KBD(wait) -1
        }
        catch {
          after cancel $status(null)
          set status(null) -1
        }
      }
      if {$curdisp ne " NVII"} {
        if {[isDescriptor $val]} { error "" "" {MATRIX} }
        ::matrix::SetElem MAT($md) $row $col $val
        if {$mode eq "regs"} {
          if {$status(user) || $user eq "user"} {
            matrix_cond_step $MAT($md)
            matrix_iterate $md
          }
        } else {
          drop
          drop
        }
      }
      seq_pending false
      set ShowX 1
      set KBD(wait) 0
    } elseif {$KBD(wait) == 1} {
      set KBD(wait) 2
    }
  }

}

# ------------------------------------------------------------------------------
proc func_sto_oper { fn param } {

  global stack storage MAT

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }
  if {$fn eq "/" && $stack(x) == 0.0} { error "" "" {ARITH INVALID} }

  set param [GETREG $param]
  if {[isDescriptor $param]} {
    lassign [matrix_getRowCol $param regs] row col
    ::matrix::SetElem MAT($param) $row $col \
      [expr [::matrix::GetElem $MAT($param) $row $col] $fn ($stack(x)*1.0)]
  } else {
    if {[isDescriptor $storage($param)]} { error "" "" {MATRIX} }

    set storage($param) [expr $storage($param) $fn ($stack(x)*1.0)]
  }

}

# ------------------------------------------------------------------------------
proc func_set_matrix { idx } {

  global stack MAT

  set md [Descriptor $idx]
  if {[isDescriptor $stack(x)]} {
    chk_matmem $md $stack(x)
    SETMAT $md $MAT($stack(x)) $MAT($stack(x)\_LU)
  } else {
    set new {}
    foreach row $MAT($md) {
      set nrow {}
      foreach col $row {
        lappend nrow $stack(x)
      }
      lappend new $nrow
    }
    SETMAT $md $new
  }

}

# ------------------------------------------------------------------------------
proc func_int {} {

  global stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set stack(x) [expr {wide($stack(x))}]

}

# ------------------------------------------------------------------------------
proc func_rcl { reg } {

  global HP15 status stack istack storage

  if {$reg ne "I" && $reg > $HP15(dataregs)} { error "" "" {INDEX} }

  if {!$status(liftlock)} {lift}
  set stack(x) $storage($reg)
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_rcl_i { {user ""} } {

  global status stack istack storage

  set reg [GETREG "(i)"]
  if {[isDescriptor $reg]} {
    func_rcl_matrix regs $user [string index $reg 1]
  } else {
    if {!$status(liftlock)} {lift}
    set stack(x) $storage($reg)
  }
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_rcl_matrix { mode {user ""} idx } {

  global HP15 status stack MAT prgstat curdisp ShowX KBD

  set md [Descriptor $idx]
  lassign [matrix_getRowCol $md $mode] row col

  if {$KBD(state) == 0 && [seq_pending] eq ""} {
    set curdisp [format " %s%3s$status(dot)%s" [matrix_name $md] [expr $row+1] [expr $col+1]]
    if {$status(null) == -1} {
      set status(null) [after 3000 disp_null]
    }
    seq_pending true
    set ShowX 0
  } else {
    if {$KBD(wait) == 0} {
      if {!$prgstat(running)} {
        set KBD(wait) 1
        while {$KBD(wait) > 0} {
          after $HP15(pause) "set KBD(release) 0"
          tkwait variable KBD(release)
          incr KBD(wait) -1
        }
        catch {
          after cancel $status(null)
          set status(null) -1
        }
      }
      if {$curdisp ne " NVII"} {
        if {$mode eq "regs"} {
          if {$status(user) || $user eq "user"} {
            matrix_cond_step $MAT($md)
            matrix_iterate $md
          }
          if {!$status(liftlock)} {lift}
        } else {
          drop
        }
        set stack(x) [::matrix::GetElem $MAT($md) $row $col]
      }
      seq_pending false
      set ShowX 1
      set KBD(wait) 0
    } elseif {$KBD(wait) == 1} {
      set KBD(wait) 2
    }
  }

}

# ------------------------------------------------------------------------------
proc func_rcl_descriptor { idx } {

  global status stack

  if {!$status(liftlock)} {lift}
  set stack(x) [Descriptor $idx]

}

# ------------------------------------------------------------------------------
proc func_rcl_oper { fn param } {

  global stack storage MAT

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set param [GETREG $param]
  if {[isDescriptor $param]} {
    lassign [matrix_getRowCol $param regs] row col
    set val [::matrix::GetElem $MAT($param) $row $col]
  } else {
    if {[isDescriptor $storage($param)]} { error "" "" {MATRIX} }

    set val $storage($param)
  }

  if {$fn eq "/" && $val == 0.0} { error "" "" {ARITH INVALID} }
  set stack(x) [expr $stack(x) $fn ($val*1.0)]

}

# ------------------------------------------------------------------------------
proc func_rclsum {} {

  global HP15 status stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs

  lift
  if {$status(liftlock) < 1} {lift}
  set stack(y) $storage(5)
  set istack(y) 0.0
  set stack(x) $storage(3)
  set istack(x) 0.0

}

# ------------------------------------------------------------------------------
proc bytecnt { st } {

  set TwoBytes {
    {[23]2_48_[0-9]$} {4[45]_.*_u} {4[45]_[1234]0_.*} {4[45]_43_24} {42_[12]0_.*}
    {42_[456]_[2-9]$} {42_[456]_1[1-5]$} {42_[456]_48_[0-9]$} {42_[789]_.*}
    {42_16_[0-9]} {42_21_48_[0-9]$} {43_[456]_.*} {44_16_1[1-5]$}
  }

  set rc 1
  foreach tb $TwoBytes {
    if {[regexp $tb $st]} {
      incr rc
      break
    }
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc mem_recalc {} {

  global HP15 FLAG PRGM

  set pbytes [prgm_len $PRGM]
  set HP15(prgmregs) [expr int(ceil($pbytes/7.0))]
  set HP15(freebytes) [expr int(($HP15(prgmregs)*7)-$pbytes)]
  set HP15(poolregsfree) [expr $HP15(totregs) - $FLAG(8)*5 - $HP15(dataregs)+1 \
    - $HP15(prgmregs) - [matrix_mem]]

}

# ------------------------------------------------------------------------------
proc func_rcl_dim_matrix { idx } {

  global status stack MAT

  set md [Descriptor $idx]
  if {!$status(liftlock)} {lift}
  lift
  set stack(y) [::matrix::Rows $MAT($md)]
  set stack(x) [::matrix::Cols $MAT($md)]

}

# ------------------------------------------------------------------------------
proc func_rcl_dim_i {} {

  global HP15 status stack istack

  if {!$status(liftlock)} {lift}
  set stack(x) $HP15(dataregs)
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_mem {} {

  global HP15 status curdisp ShowX KBD

  if {$KBD(state) == 0 && [seq_pending] eq ""} {
    mem_recalc
    if {$HP15(totregs) > 64} {
      set memfmt "%3d$status(dot)%3d$status(dot)%3d-%d"
    } else {
      set memfmt "%3d%3d%3d-%d"
    }
    set curdisp [format $memfmt \
      $HP15(dataregs) $HP15(poolregsfree) $HP15(prgmregs) $HP15(freebytes)]
    seq_pending true
    set ShowX 0
  } else {
    if {$KBD(wait) == 0} {
      set KBD(wait) 1
      while {$KBD(wait) > 0} {
        after $HP15(pause) "set KBD(release) 0"
        tkwait variable KBD(release)
        incr KBD(wait) -1
      }
      seq_pending false
      set ShowX 1
      if {$status(liftlock) > 0} {set status(liftlock) 2}
      set KBD(wait) 0
    } elseif {$KBD(wait) == 1} {
      set KBD(wait) 2
    }
  }

}

# ------------------------------------------------------------------------------
proc func_random {} {

  global status stack istack

  if {!$status(liftlock)} {lift}
  set status(seed) [expr (1574352261 * $status(seed) + 1017980433) % 10000000000]
  set stack(x) [expr {$status(seed)/1e10}]
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_storandom {} {

  global status stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set ax [expr abs($stack(x))]
  set expo 1e[expr {$ax < 1.0 ? 10 : 9-int(log10($ax))}]
  set status(seed) [format "%10.0f" [expr {$ax*$expo}]]

}

# ------------------------------------------------------------------------------
proc func_rclrandom {} {

  global status stack istack

  if {!$status(liftlock)} {lift}
  set stack(x) [expr $status(seed)/1e10]
  if {$status(ixclear)} {set istack(x) 0.0}

}

# ------------------------------------------------------------------------------
proc func_polar {} {

  global PI status FLAG stack istack

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }

  if {$FLAG(8)} {
    move x u
    set istack(x) [expr {[cphi]*$status(rangle)/$PI}]
    set stack(x) [cabs]
  } else {
    move y u
    set stack(y) [expr {$status(rangle)*atan2($stack(u), $stack(x))/$PI}]
    set stack(x) [expr {sqrt($stack(x)*$stack(x) + $stack(u)*$stack(u))}]
  }

}

# ------------------------------------------------------------------------------
proc faculty { var } {

  if {$var > 69} { error "" "" {ARITH OVERFLOW} }

  set res 1.0
  set var [expr int($var)]
  for {set ii $var} {$ii > 1} {incr ii -1} {
    set res [expr $res * $ii]
  }
  return $res

}

# ------------------------------------------------------------------------------
# More accurate Spouge gamma function with reflection
proc gamma { var } {

  global PI

  array set KC {
    0 2.5066282746310002e0
    1 1.9858006271387744e5
    2 -6.9653800715380232e5
    3 9.8452469720040914e5
    4 -7.1948138054635748e5
    5 2.9026275410926092e5
    6 -6.4035016015929323e4
    7 7.2018644207650377e3
    8 -3.5497463894564885e2
    9 5.6610056376747284e0
    10 -1.4743849521331020e-2
    11 7.4908560087605962e-7
  }

  if {$var < -10.0} {
    return [expr ($PI / (sin($PI * $var) * [gamma [expr 1.0 - $var]]))]
  } else {
    set accm [expr $KC(0)]
    for {set k 1} {$k < 12} {incr k} {
      set accm [expr $accm + ($KC($k) / [expr $var + $k])]
    }
    set accm [expr ($accm * exp([expr {-1.0 * ($var + 12.0)}]) * \
              pow([expr {$var + 12.0}],[expr {$var + 0.5}]))]

    return [expr {$accm / $var}]
  }

}

# ------------------------------------------------------------------------------
proc func_faculty {} {

  global stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {$stack(x) >= 0.0 && $stack(x) == int($stack(x))} {
    set stack(x) [faculty $stack(x)]
  } else {
    if {$stack(x) > 69.95757445} { error "" "" {ARITH OVERFLOW} }
    if {$stack(x) < 0.0 && $stack(x) == int($stack(x))} {
      error "" "" {ARITH NOVERFLOW}
    }
    if {$stack(x) < -71.06400563} {
      set stack(x) 0.0
    } else {
      set stack(x) [gamma [expr {$stack(x) + 1.0}]]
    }
  }

}

# ------------------------------------------------------------------------------
proc chk_sumregs {} {

  global storage

  for {set ii 1} {$ii < 8} {incr ii} {
    if {[isDescriptor $storage($ii)]} { error "" "" {MATRIX} }
  }

}

# ------------------------------------------------------------------------------
proc func_avg {} {

  global HP15 status stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs
  if {abs($storage(2)) <= 0.0} { error "" "" {SUM} }

  lift
  if {!$status(liftlock)} {lift}
  set stack(y) [expr {$storage(5)/$storage(2)}]
  set istack(y) 0.0
  set istack(x) 0.0
  set stack(x) [expr {$storage(3)/$storage(2)}]

}

# ------------------------------------------------------------------------------
proc func_linexpolation {} {

  global HP15 stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs
  if {abs($storage(2)) < 1} { error "" "" {SUM} }

  move x s
  lift
  set M [expr {$storage(2)*$storage(4)-$storage(3)*$storage(3)}]
  set N [expr {$storage(2)*$storage(6)-$storage(5)*$storage(5)}]
  set P [expr {$storage(2)*$storage(7)-$storage(3)*$storage(5)}]
  set istack(x) 0.0
  set istack(y) 0.0
  set stack(y) [expr {$P/sqrt($M*$N)}]
  set stack(x) [expr {($M*$storage(5) + \
    $P*($storage(2)*$stack(s) - $storage(3)) ) / ($storage(2)*$M)}]

}

# ------------------------------------------------------------------------------
proc func_linreg {} {

  global HP15 status stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs
  if {abs($storage(2)) < 1} { error "" "" {SUM} }

  lift
  if {!$status(liftlock)} {lift}
  set M [expr {$storage(2)*$storage(4)-$storage(3)*$storage(3)}]
  set N [expr {$storage(2)*$storage(6)-$storage(5)*$storage(5)}]
  set P [expr {$storage(2)*$storage(7)-$storage(3)*$storage(5)}]
  set istack(y) 0.0
  set istack(x) 0.0
  set stack(y) [expr {$P/$M}]
  set stack(x) [expr {($M*$storage(5) - $P*$storage(3))/($storage(2)*$M)}]

}

# ------------------------------------------------------------------------------
proc func_stddev {} {

  global HP15 status stack istack storage

  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs
  if {abs($storage(2)) == 0.0} { error "" "" {SUM} }

  lift
  if {!$status(liftlock)} {lift}
  set DIVISOR [expr {$storage(2)*($storage(2)-1.0)}]
  set istack(y) 0.0
  set istack(x) 0.0
  set stack(y) \
    [expr {sqrt(($storage(2)*$storage(6)-$storage(5)*$storage(5))/$DIVISOR)}]
  set stack(x) \
    [expr {sqrt(($storage(2)*$storage(4)-$storage(3)*$storage(3))/$DIVISOR)}]

}

# ------------------------------------------------------------------------------
proc func_sum_plus {} {

  global HP15 stack storage

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }
  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs

  set storage(2) [expr {$storage(2) + 1}]
  set storage(3) [expr {$storage(3) + $stack(x)}]
  set storage(4) [expr {$storage(4) + $stack(x)*$stack(x)}]
  set storage(5) [expr {$storage(5) + $stack(y)}]
  set storage(6) [expr {$storage(6) + $stack(y)*$stack(y)}]
  set storage(7) [expr {$storage(7) + $stack(x)*$stack(y)}]
  set stack(x) $storage(2)

}

# ------------------------------------------------------------------------------
proc func_sum_minus {} {

  global HP15 stack storage

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }
  if {$HP15(dataregs) < 7} { error "" "" {INDEX} }
  chk_sumregs

  set storage(2) [expr {$storage(2) - 1}]
  set storage(3) [expr {$storage(3) - $stack(x)}]
  set storage(4) [expr {$storage(4) - $stack(x)*$stack(x)}]
  set storage(5) [expr {$storage(5) - $stack(y)}]
  set storage(6) [expr {$storage(6) - $stack(y)*$stack(y)}]
  set storage(7) [expr {$storage(7) - $stack(x)*$stack(y)}]
  set stack(x) $storage(2)

}

# ------------------------------------------------------------------------------
proc func_Pyx {} {

  global stack MAT

  if {[isDescriptor $stack(x)]} {
    if {[::matrix::Cols $MAT($stack(x))] % 2 != 0} { error "" "" {DIMMAT} }

    move LSTx s
    SETMAT $stack(x) [::matrix::ZP $MAT($stack(x))]
  } else {
    if {[isDescriptor $stack(y)]} { error "" "" {MATRIX} }
    if {$stack(x) - int($stack(x)) > 0 || $stack(x) < 0 || \
        $stack(y) - int($stack(y)) > 0 || $stack(y) < 0 || \
        $stack(x) > $stack(y)} {
      error "" "" {ARITH INVALID}
    }

    set rc 1
    for {set ii [expr int($stack(y))]} {$ii > $stack(y) - $stack(x)} {incr ii -1} {
      set rc [expr $ii*$rc]
    }
    set stack(y) $rc
    drop
  }

}

# ------------------------------------------------------------------------------
proc func_Cyx {} {

  global stack MAT

  if {[isDescriptor $stack(x)]} {
    if {[::matrix::Rows $MAT($stack(x))] % 2 != 0} { error "" "" {DIMMAT} }

    move LSTx s
    SETMAT $stack(x) [::matrix::ZC $MAT($stack(x))]
  } else {
    if {[isDescriptor $stack(y)]} { error "" "" {MATRIX} }
    if {$stack(x) - int($stack(x)) > 0 || $stack(x) < 0 || \
        $stack(y) - int($stack(y)) > 0 || $stack(y) < 0 || \
        $stack(x) > $stack(y)} {
      error "" "" {ARITH INVALID}
    }

    if {$stack(x) > 69 || $stack(y) > 69} {
      set stack(y) [::math::choose $stack(y) $stack(x)]
    } else {
      set stack(y) [expr round([faculty $stack(y)]/ \
        ([faculty $stack(x)]*[faculty [expr int($stack(y)-$stack(x))]]))]
    }
    drop
  }

}

# ------------------------------------------------------------------------------
proc func_enter {} {

  global FLAG stack istack

  if {![isDescriptor $stack(x)] && \
    [string first "." $stack(x)] < 0 && [string first "e" $stack(x)] < 0} {
    append stack(x) ".0"
  }
  foreach {r1 r2} {t z z y y x} {
    set stack($r1) $stack($r2)
  }

  if {$FLAG(8)} {
    if {[string first "." $istack(x)] < 0 && [string first "e" $istack(x)] < 0} {
      append istack(x) ".0"
    }
    foreach {r1 r2} {t z z y y x} {
      set istack($r1) $istack($r2)
    }
  }

}

# ------------------------------------------------------------------------------
proc func_lastx {} {

  global status FLAG stack istack

  if {!$status(liftlock)} {lift}
  set stack(x) $stack(LSTx)
  if {$FLAG(8)} {set istack(x) $istack(LSTx)}

}

# ------------------------------------------------------------------------------
proc func_rectangular {} {

  global status FLAG stack istack PI

  if {[isDescriptor $stack(x)] || [isDescriptor $stack(y)]} {
    error "" "" {MATRIX}
  }

  if {$FLAG(8)} {
    set yy [expr {$istack(x)/$status(rangle)}]
    set ychk [expr {$yy - (floor($yy/2.0)*2.0)}]
    if {$ychk == 0.0} {
      set istack(x) 0.0
    } elseif {$ychk == 0.5} {
      set istack(x) $stack(x)
      set stack(x) 0.0
    } elseif {$ychk == 1.0} {
      set istack(x) 0.0
      set stack(x) [expr {-$stack(x)}]
    } elseif {$ychk == 1.5} {
      set istack(x) [expr {-$stack(x)}]
      set stack(x) 0.0
    } else {
      set istack(x) [expr {sin($yy*$PI)*$stack(x)}]
      set stack(x) [expr {cos($yy*$PI)*$stack(x)}]
    }
  } else {
    set yy [expr {$stack(y)/$status(rangle)}]
    set ychk [expr {$yy - (floor($yy/2.0)*2.0)}]
    if {$ychk == 0.0} {
      set stack(y) 0.0
    } elseif {$ychk == 0.5} {
      set stack(y) $stack(x)
      set stack(x) 0.0
    } elseif {$ychk == 1.0} {
      set stack(y) 0.0
      set stack(x) [expr {-$stack(x)}]
    } elseif {$ychk == 1.5} {
      set stack(y) [expr {-$stack(x)}]
      set stack(x) 0.0
    } else {
      set stack(y) [expr {sin($yy*$PI)*$stack(x)}]
      set stack(x) [expr {cos($yy*$PI)*$stack(x)}]
    }
  }

}

# ------------------------------------------------------------------------------
proc func_hms {} {

  global stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set hours [expr {int($stack(x))}]
  set minutes [expr {($stack(x) - $hours)*0.6}]
  if {abs($minutes - [format "%2.2f" $minutes]) < 1E-8} {
    set minutes [format "%0.4f" $minutes]
  } else {
    set minutes [expr {int($minutes*100.0)/100.0}]
  }
  set seconds [expr {($stack(x) - $hours - $minutes/0.6)*0.36}]
  set stack(x) [expr {$hours + $minutes + $seconds}]

}

# ------------------------------------------------------------------------------
proc func_h {} {

  global stack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set hours [expr {int($stack(x))}]
  set minutes [expr ($stack(x) - $hours)*100.0]
  if {abs($minutes - round($minutes)) < 1E-8} {
    set minutes [expr round($minutes)]
  } else {
    set minutes [expr int($minutes)]
  }
  set seconds [format "%.10f" [expr abs($stack(x) - $hours - $minutes/100.0)*1E4]]
  set stack(x) [expr {$hours + ($minutes*60.0+$seconds)/3600.0}]

}

# ------------------------------------------------------------------------------
proc func_rad {} {

  global stack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set stack(x) [expr {$stack(x)*$PI/180.0}]

}

# ------------------------------------------------------------------------------
proc func_deg {} {

  global stack PI

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  set stack(x) [expr {$stack(x)*180.0/$PI}]

}

# ------------------------------------------------------------------------------
proc func_re_im {} {

  global FLAG stack istack

  if {[isDescriptor $stack(x)]} { error "" "" {MATRIX} }

  if {!$FLAG(8)} {func_sf 8}
  set tmp [expr {$stack(x)*1.0}]
  set stack(x) $istack(x)
  set istack(x) $tmp

}

# ------------------------------------------------------------------------------
proc func_test { op } {

  global FLAG stack istack prgstat

  if {[isDescriptor $stack(x)] && $op in {1 2 3 4 7 8 9 10} } {
    error "" "" {MATRIX}
  }

  switch $op {
    0 {if {[isDescriptor $stack(x)]} {
         set rc 1
       } elseif {$FLAG(8)} {
         set rc [expr {$stack(x) != 0.0 || $istack(x) != 0.0}]
       } else {
         set rc [expr $stack(x) != 0.0]
       }
      }
    1 {set rc [expr $stack(x) >  0.0]}
    2 {set rc [expr $stack(x) <  0.0]}
    3 {set rc [expr $stack(x) >= 0.0]}
    4 {set rc [expr $stack(x) <= 0.0]}
    5 {if {$FLAG(8) && ![isDescriptor $stack(x)]} {
         set rc [expr {$stack(x) == $stack(y) && $istack(x) == $istack(y)}]
       } else {
         set rc [expr {$stack(x) == $stack(y)}]
       }
      }
    6 {if {$FLAG(8) && ![isDescriptor $stack(x)]} {
         set rc [expr {$stack(x) != $stack(y) || $istack(x) != $istack(y)} ]
       } else {
         set rc [expr {$stack(x) != $stack(y)}]
       }
      }
    7 {set rc [expr {$stack(x) >  $stack(y)}]}
    8 {set rc [expr {$stack(x) <  $stack(y)}]}
    9 {set rc [expr {$stack(x) >= $stack(y)}]}
   10 {set rc [expr {$stack(x) <= $stack(y)}]}
   11 {if {[isDescriptor $stack(x)]} {
         set rc 0
       } elseif {$FLAG(8)} {
         set rc [expr {$stack(x) == 0.0 && $istack(x) == 0.0}]
       } else {
         set rc [expr {$stack(x) == 0.0}]
       }
      }
  }
  if {$prgstat(running)} {
    set ii [expr $rc ? 1 : 2]
  } else {
    set ii [expr $rc ? 0 : 1]
  }
  prgm_incr $ii

}

# ------------------------------------------------------------------------------
proc func_plus {} {

  global status FLAG stack istack MAT

  set xy "[isDescriptor $stack(x)][isDescriptor $stack(y)]"
  if {$xy eq "00"} {
    set stack(y) [expr {$stack(y) + ($stack(x)*1.0)}]
    if {$FLAG(8)} {set istack(y) [expr {$istack(y) + ($istack(x)*1.0)}]}
  } else {
    switch $xy {
      "11" {
        if {![::matrix::Conforming shape $MAT($stack(x)) $MAT($stack(y))]} {
          error "" "" {DIMMAT}
        }
        chk_matmem $status(result) $stack(x)
        SETMAT $status(result) [::matrix::Add $MAT($stack(y)) $MAT($stack(x))]
      }
      "10" {
        chk_matmem $status(result) $stack(x)
        SETMAT $status(result) [::matrix::ScalarOpMat $stack(y) $MAT($stack(x)) "+"]
      }
      "01" {
        chk_matmem $status(result) $stack(y)
        SETMAT $status(result) [::matrix::MatOpScalar $MAT($stack(y)) $stack(x) "+"]
      }
    }
    if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
    set stack(y) $status(result)
  }
  drop

}

# ------------------------------------------------------------------------------
proc func_minus {} {

  global status FLAG stack istack MAT

  set xy "[isDescriptor $stack(x)][isDescriptor $stack(y)]"
  if {$xy eq "00"} {
    set stack(y) [expr {$stack(y) - $stack(x)}]
    if {$FLAG(8)} {set istack(y) [expr {$istack(y) - (1.0 * $istack(x))}]}
  } else {
    switch $xy {
      "11" {
        if {![::matrix::Conforming shape $MAT($stack(x)) $MAT($stack(y))]} {
          error "" "" {DIMMAT}
        }
        chk_matmem $status(result) $stack(x)
        SETMAT $status(result) [::matrix::Sub $MAT($stack(y)) $MAT($stack(x))]
      }
      "10" {
        chk_matmem $status(result) $stack(x)
        SETMAT $status(result) [::matrix::ScalarOpMat $stack(y) $MAT($stack(x)) "-"]
      }
      "01" {
        chk_matmem $status(result) $stack(y)
        SETMAT $status(result) [::matrix::MatOpScalar $MAT($stack(y)) $stack(x) "-"]
      }
    }
    if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
    set stack(y) $status(result)
  }
  drop

}

# ------------------------------------------------------------------------------
proc func_mult {} {

  global status FLAG stack MAT

  set xy "[isDescriptor $stack(x)][isDescriptor $stack(y)]"
  if {$xy eq "00"} {
    if {$FLAG(8)} {
      move y m
      move x u
      cmul
      move u y
    } else {
      set stack(y) [expr {$stack(x)*$stack(y)*1.0}]
    }
  } else {
    switch $xy {
      "11" {
        if {($status(result) == $stack(x) || $status(result) == $stack(y)) ||
            ![::matrix::Conforming matmul $MAT($stack(y)) $MAT($stack(x))]} {
          error "" "" {DIMMAT}
        }
        chk_matmem $status(result) \
          [expr [::matrix::Rows $MAT($stack(y))]*[::matrix::Cols $MAT($stack(x))]]
        SETMAT $status(result) [::matrix::Multiply $MAT($stack(y)) $MAT($stack(x))]
      }
      "10" {
        chk_matmem $status(result) $stack(x)
        SETMAT $status(result) [::matrix::ScalarOpMat $stack(y) $MAT($stack(x)) "*"]
      }
      "01" {
        chk_matmem $status(result) $stack(y)
        SETMAT $status(result) [::matrix::MatOpScalar $MAT($stack(y)) $stack(x) "*"]
      }
    }
    if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
    set stack(y) $status(result)
  }
  drop

}

# ------------------------------------------------------------------------------
proc func_div {} {

  global status FLAG stack MAT

  set xy "[isDescriptor $stack(x)][isDescriptor $stack(y)]"
  if {$xy eq "00"} {
    if {$FLAG(8)} {
      move y m
      move x u
      cdiv
      move u y
    } else {
      if {$stack(x) == 0.0} { error "" "" {ARITH INVALID} }
      set stack(y) [expr {$stack(y)/($stack(x)*1.0)}]
    }
  } else {
    switch $xy {
      "11" {
        if {$status(result) == $stack(x) ||
            [::matrix::Rows $MAT($stack(x))] != [::matrix::Cols $MAT($stack(x))] ||
            [::matrix::Rows $MAT($stack(y))] != [::matrix::Cols $MAT($stack(x))]} {
          error "" "" {DIMMAT}
        }
        chk_matmem $status(result) $stack(x)

        if {[catch {
# Use a copy of Matrix in Y register in case X- and Y-register are the same
          set ysave $MAT($stack(y))
          if {[isLU $stack(x)]} {
            set pivot $MAT($stack(x)\_LU)
          } else {
            set pivot [::matrix::dgetrf MAT($stack(x))]
            SETMAT $stack(x) $MAT($stack(x)) $pivot
          }
          SETMAT $status(result) [::matrix::solvePGauss $MAT($stack(x)) $ysave $pivot]
        }]} {
          error "" "" {ARITH INVALID}
        }
      }
      "10" {
        if {[::matrix::Rows $MAT($stack(x))] != [::matrix::Cols $MAT($stack(x))]} {
          error "" "" {DIMMAT}
        }
        chk_matmem $status(result) $stack(x)

        set mID [::matrix::mkIdentity [::matrix::Rows $MAT($stack(x))]]
        if {[isLU $stack(x)]} {
          set pivot $MAT($stack(x)\_LU)
        } else {
          set pivot {}
        }
        set Xinv [::matrix::solvePGauss $MAT($stack(x)) $mID $pivot]
        SETMAT $status(result) [::matrix::ScalarOpMat $stack(y) $Xinv "*"]
      }
      "01" {
        chk_matmem $status(result) $stack(y)

        SETMAT $status(result) [::matrix::MatOpScalar $MAT($stack(y)) $stack(x) "/"]
      }
    }
    if {$::matrix::OVERFLOW} { set FLAG(9) 1 }
    set stack(y) $status(result)
  }
  drop

}

# ------------------------------------------------------------------------------
proc show_prgm { trigger } {

  global HP15 status prgstat PRGM

  set plines {}
  set wid 10
  if {!$HP15(mnemonics)} {
    set wid 9
  } else {
    if {[lsearch $PRGM {43_22_*}] >= 0} { set wid 11 }
    if {[lsearch $PRGM {4[245]_16_*}] >= 0} { set wid 12 }
  }

  if {[tk windowingsystem] eq "x11"} {
    set fmt " %03d"
  } else {
    set fmt "%03d"
  }

  for {set ii 0} {$ii < [llength $PRGM]} {incr ii} {
    set lbl [format $fmt $ii]
    set seq [lindex $PRGM $ii]
    append lbl [lindex {"-" "u"} [regexp {_u$} $seq]]
    if {$HP15(mnemonics)} {
      append lbl [format_mnemonic $seq $wid]
    } else {
      append lbl [format_keyseq $seq $wid]
    }

    if {$status(PRGM)} {
      set cmd "set prgstat(curline) $ii; show_curline"
    } else {
      set cmd "set prgstat(curline) $ii"
    }
    lappend plines [list $seq $lbl $cmd]
  }

  if {[tk windowingsystem] eq "aqua"} {
    show_prgm_macos $trigger $plines $wid
  } else {
    show_prgm_std $trigger $plines
  }

}

# ------------------------------------------------------------------------------
proc show_prgm_std { trigger plines } {

  global LAYOUT HP15

  if {[winfo exists .prgm]} {destroy .prgm}

  menu .prgm -title [mc gen.program] -font $LAYOUT(FnMenu)
  set ii 0
  foreach ll $plines {
    .prgm add command -label [lindex $ll 1] -command [lindex $ll 2]
    if {$HP15(prgmmenubreak) && $ii % $HP15(prgmmenubreak) == 0} {
      .prgm entryconfigure $ii -columnbreak 1
    }

    if {$HP15(prgmcoloured)} {
      switch -regexp [lindex $ll 0] {
        "^42_21.*" {
          .prgm entryconfigure $ii -foreground $LAYOUT(fbutton_bg) \
            -background $LAYOUT(button_bg)
        }
        "^43_32.*" {
          .prgm entryconfigure $ii -foreground $LAYOUT(gbutton_bg) \
            -background $LAYOUT(button_bg)        }
        "^22_.*"   -
        "^32_.*"   {
          .prgm entryconfigure $ii -foreground white \
            -background $LAYOUT(button_bg)
        }
      }
    }
    incr ii
  }

  if {$trigger eq "MOUSE"} {
    tk_popup .prgm [winfo pointerx .] [winfo pointery .]
  } else {
    tk_popup .prgm [expr [guipos dspbg x1]+6] [guipos dspbg y2]
  }

}

# ------------------------------------------------------------------------------
proc show_prgm_macos { trigger plines wid } {

  global LAYOUT HP15

  set CFG(enter) \
     "-background systemAlternatePrimaryHighlightColor -foreground white"
  set CFG(normal) "-background white -foreground black"
  set CFG(fline) "-foreground $LAYOUT(fbutton_bg) -background $LAYOUT(button_bg)"
  set CFG(gline) "-foreground $LAYOUT(gbutton_bg) -background $LAYOUT(button_bg)"
  set CFG(jline) "-foreground white -background $LAYOUT(button_bg)"

  if {[winfo exists .popup]} {destroy .popup}

  set wid [expr int(ceil([llength $plines]*1.0/$HP15(prgmmenubreak)))*($wid+9)+1]
  set hei [tcl::mathfunc::min $HP15(prgmmenubreak) [llength $plines]]

  toplevel .popup
  wm title .popup "[mc gen.program]: $HP15(prgmname)"
  text .popup.text -font $LAYOUT(FnMenu) -height $hei \
    -width $wid -relief raised -wrap none -spacing1 4
  pack .popup.text -expand yes -fill both

  set ii 0
  foreach ll $plines {
# Tagging
    if {$HP15(prgmcoloured)} {
      switch -regexp [lindex $ll 0] {
        "^42_21.*" {set ctag fline}
        "^43_32.*" {set ctag gline}
        "^22_.*"   -
        "^32_.*"   {set ctag jline}
        default {set ctag normal}
      }
    } else {
      set ctag normal
    }

    set line [expr ($ii % $HP15(prgmmenubreak)) + 1]
    .popup.text insert $line.end " "
    .popup.text insert $line.end "  [lindex $ll 1]  " [list ltag$ii $ctag]
    if {$ii < $HP15(prgmmenubreak)-1} {
      .popup.text insert end "\n"
    }
    .popup.text tag bind ltag$ii <Enter> \
      ".popup.text tag configure ltag$ii $CFG(enter)"
    .popup.text tag bind ltag$ii <Leave> \
      ".popup.text tag configure ltag$ii $CFG($ctag)"
    .popup.text tag bind ltag$ii <ButtonPress> "destroy_modal .popup; [lindex $ll 2]"
    incr ii
  }

  if {$HP15(prgmcoloured)} {
    .popup.text tag configure fline {*}$CFG(fline)
    .popup.text tag configure gline {*}$CFG(gline)
    .popup.text tag configure jline {*}$CFG(jline)
  }

  if {$trigger eq "MOUSE"} {
    set px [winfo pointerx .]
    set py [winfo pointery .]
  } else {
    set px [expr [guipos dspbg x1]+6]
    set py [guipos dspbg y2]
  }

  if {$px + [winfo width .popup] > [winfo screenwidth .popup]} {
    set px [expr [winfo screenwidth .popup] - [winfo width .popup] - 20]
  }
  if {$py + [winfo height .popup] + 100 > [winfo screenheight .popup]} {
    set py [expr [winfo screenheight .popup] - [winfo height .popup] - 100]
  }

  wm transient .popup .
  wm resizable .popup false false

  bind .popup <Escape> "destroy_modal %W"
  bind .popup <FocusOut> "destroy_modal %W"
  wm protocol .popup WM_DELETE_WINDOW "destroy_modal .popup"

  raise .popup
  grab .popup
  focus .popup

}

# ------------------------------------------------------------------------------
proc show_curline {} {

  global curdisp prgstat PRGM

  set seq [lindex $PRGM $prgstat(curline)]
  set user [lindex {"-" "u"} [regexp {_u$} $seq]]
  set curdisp [format " %03d" $prgstat(curline)]$user[format_keyseq $seq 6]

}

# ------------------------------------------------------------------------------
proc prgm_len { prgm } {

  set rc -1
  foreach st $prgm {
    incr rc [bytecnt $st]
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc prgm_addstep { step } {

  global HP15 prgstat PRGM

  if {($HP15(poolregsfree)*7 + $HP15(freebytes) - [bytecnt $step] >= 0) &&
      ($prgstat(curline) < 999)} {
    set PRGM [linsert $PRGM [expr $prgstat(curline)+1] $step]
    incr prgstat(curline)
    show_curline
    mem_recalc
  } else {
    error_handler { ADDRESS }
  }

}

# ------------------------------------------------------------------------------
proc prgm_interrupt {} {

  global prgstat

  set prgstat(interrupt) 1

}

# ------------------------------------------------------------------------------
proc prgm_incr { nn } {

  global prgstat PRGM

  set prgstat(curline) [expr {($prgstat(curline)+$nn) % [llength $PRGM]}]

}

# ------------------------------------------------------------------------------
proc prgm_addrtn { adr } {

  global prgstat

  if {!$prgstat(interrupt)} {
    if {!($adr == 0 && [llength $prgstat(rtnadr)] == 0)} {
      lappend prgstat(rtnadr) $adr
    }
  }

}

# ------------------------------------------------------------------------------
proc prgm_purgertn {} {

  global prgstat

  if {[llength $prgstat(rtnadr)] > 0} {
    set prgstat(rtnadr) [lsearch -all -inline -not -exact $prgstat(rtnadr) 0]
  } else {
    set prgstat(rtnadr) {}
  }

}

# ------------------------------------------------------------------------------
proc prgm_step {} {

  global status prgstat PRGM

  if {$prgstat(interrupt) && $status(num)} { return }

  set oldline $prgstat(curline)
  dispatch_key [lindex $PRGM $prgstat(curline)]
  if {$prgstat(curline) == 0} {
    set prgstat(running) 0
  } elseif {$prgstat(curline) == [llength $PRGM]-1} {
# Implicit return at end of program code
    if {$oldline == $prgstat(curline)} {
      dispatch_key 43_32
      dispatch_key [lindex $PRGM $prgstat(curline)]
    }
  } elseif {$oldline == $prgstat(curline) && !$status(error)} {
    prgm_incr 1
  }

}

# ------------------------------------------------------------------------------
proc prgm_run { start } {

  global HP15 curdisp status prgstat blink_t blink_id

# Nested calls occur when using SOLVE and INTEGRATE
  if {$prgstat(running)} {
    set recursive 1
  } else {
# Release key before running the program or it remains pressed
    if {[.gui gettags pressed] ne "" } {
      key_release [lindex [.gui gettags pressed] 0]
      update
    }
    set prgstat(running) 1
  }

  set prgstat(curline) $start

  while {$prgstat(running)} {
    if {[clock milliseconds] > $blink_t} {
      if {$blink_id == 0} {
        set curdisp "  running"
        set blink_id 1
      } else {
        set curdisp ""
        set blink_id 0
      }
      update
      set blink_t [expr [clock milliseconds]+300]
    }
    after $HP15(delay)
    prgm_step
    if {($prgstat(interrupt) && $status(num)) || $status(error)} {
      set prgstat(running) 0
    }
  }

  if {[info exists recursive]} { set prgstat(running) 1 }
  set status(num) 1
  if {$prgstat(interrupt)} { error "" "" {INTERRUPT} }

  if {($status(error) | $prgstat(running) | $status(integrate) | $status(solve)) == 0} {
    show_x
  }


}

# ------------------------------------------------------------------------------
proc func_pse {} {

  global HP15 status

  set status(num) 1
  show_x
  update
  after $HP15(pause)
  if {$status(liftlock) > 0} {set status(liftlock) 2}

}

# ------------------------------------------------------------------------------
proc func_rs {} {

  global status prgstat KBD keyseq

  if {$prgstat(running)} {
    set prgstat(running) 0
    update
  } else {
    if {$KBD(state) == 0} {
      set status(num) 1
      if {$prgstat(curline) == 0} {
        prgm_incr 1
      }
      show_curline
      seq_pending true
    } else {
      seq_pending false
      set keyseq ""
      prgm_run $prgstat(curline)
    }
  }
  if {$status(liftlock) > 0} {set status(liftlock) 2}

}

# ------------------------------------------------------------------------------
proc func_pr {} {

  global status FLAG blinkpr

  set_status PRGM
  if {$status(PRGM)} {
    set blinkpr $FLAG(9)
    set FLAG(9) 0
    show_curline
  } else {
    set status(num) 1
    set FLAG(9) $blinkpr
    show_x
  }
  if {$status(liftlock) > 0} {set status(liftlock) 2}

}

# ------------------------------------------------------------------------------
proc func_rtn {} {

  global prgstat

  if {[llength $prgstat(rtnadr)] > 0} {
    set prgstat(curline) [lindex $prgstat(rtnadr) end]
  } else {
    set prgstat(curline) 0
  }
  set prgstat(rtnadr) [lreplace $prgstat(rtnadr) end end]

}

# ------------------------------------------------------------------------------
proc func_on {} {

  global APPDATA

  set answer [tk_messageBox -type okcancel -icon question -default ok \
        -title $APPDATA(title) -message [mc app.exitquest]]

  if {$answer eq "ok"} {
    exit
# WA-Unix: The ON key remains pressed when the messageBox fires to early
  } elseif {$::tcl_platform(platform) eq "unix" && \
      [lindex [.gui gettags pressed] 0] eq "btn_41"} {
    key_release 41
  }

}

# ------------------------------------------------------------------------------
proc lookup_keyseq { keyseq } {

  global HP15_KEY_FUNCS

  if {$keyseq eq ""} {
    return ""
  }

  lassign [split $keyseq "_"] ind0 ind1
  if {$ind0 in {42 43 44 45} } {
    if {$ind1 eq ""} { return "" }
    set idx "$ind0\_[expr $ind1/10]"
  } else {
    set idx [expr $ind0/10]
  }

  foreach ff $HP15_KEY_FUNCS($idx) {
    if {[regexp [lindex $ff 0] $keyseq]} {
      return $ff
    }
  }
}

# ------------------------------------------------------------------------------
proc lookup_match { keyseq } {

  global HP15_KEY_FUNCS

  if {$keyseq in {42 43 44 45}} {
    return "sequence"
  } elseif {$keyseq eq ""} {
    return ""
  }

  lassign [split $keyseq "_"] ind0 ind1
  if {$ind0 in {42 43 44 45} } {
    if {$ind1 eq ""} { set ind1 0 }
    set idx "$ind0\_[expr $ind1/10]"
  } else {
    set idx [expr $ind0/10]
  }

  foreach ff $HP15_KEY_FUNCS($idx) {
    if {[string match "^$keyseq\_*" [lindex $ff 0]]} {
      return $ff
    }
  }

}

# ------------------------------------------------------------------------------
proc check_attributes { func } {

  global stack

# Numbers with leading zeros are interpreted as octal number by the Tcl/Tk
# interpreter. Must manipulate stack(x) value for most of the functions.
  if {[regexp {^\-?0+[1-9]} $stack(x)] &&
      !([lindex $func 0] in {func_digit func_EEX func_point func_chs func_bs})} {
    regsub {^(\-?)0+} $stack(x) {\1} stack(x)
  }

}

# ------------------------------------------------------------------------------
proc dispatch_key { kcode } {

  global status prgstat keyseq ShowX

  if {$status(error)} {
    set status(error) 0
    disp_refresh
    return
  }

  if {$keyseq eq ""}  {
    set keyseq $kcode
  } else {
    if {$kcode in {42 43} && $keyseq in {42 43}} {
      set keyseq $kcode
    } else {
     append keyseq "\_$kcode"
      # This will allow abbreviated key sequences. Except for STO/RCL g
      if {[regexp {^4[45]_43.*} $keyseq]} {
        if {[regexp {^4[45]_43_4[23]} $keyseq]} {
        # f or blue/gold label pressed after STO-g, continue with label function
          regsub {^4[45]_4[23]_} $keyseq "" keyseq
        } elseif {[regexp {^4[45]_43_} $keyseq] && ![regexp {(1[1-5]|24)} $kcode]} {
        # Not A-E pressed after STO-g, continue with g-key
          regsub {^4[45]_} $keyseq "" keyseq
        }
      } else {
        regsub {_4[23]} $keyseq "" keyseq
      }
      if {!($kcode in {42 43})} {
        set_status fg_off
      }
    }
  }
  set fmatch [lookup_keyseq $keyseq]

  if {$fmatch ne ""} {
# Key sequence matches a function
    lassign $fmatch kseq func alstx anum aprgm
    if {$status(PRGM) && $aprgm} {
      regsub {^42_(1[1-5])$} $keyseq {\1} keyseq
      if {$status(user) && [regexp {^4[45]_(1[1-5]|24)$} $keyseq]} {
        append keyseq "_u"
      }
      prgm_addstep $keyseq
    } else {
      if {!$status(num)} {check_attributes $func}
      if {$alstx} {move x s}
      regexp $kseq $keyseq mvar svar
# This is where all func_tions are executed
      if {[catch {
        {*}$func$svar
      }]} {error_handler $::errorCode}
      if {$anum} {
        set status(num) 1
        if {!$prgstat(running) && !$status(error) && $ShowX} {
          disp_refresh
        }
      }
      if {$alstx && !$status(error) && $status(num)} {move s LSTx}
    }
    if {$aprgm} {
      if {$kseq in {{^36$} {^43_35$} {^49$} {^43_49$}}} {
        set status(liftlock) 1
      } else {
        if {$status(liftlock) > 0} {incr status(liftlock) -1}
      }
    }
    if {$kseq ne {^21$}} {
      set status(ixclear) [expr {$kseq in {{^36$} {^49$} {^43_49$}}}]
    }
    set keyseq ""
    if {!$prgstat(running)} { seq_indicator }
  } else {
# If key sequence doesn't match exactly check for longer one.
    set seq [lookup_match $keyseq]

# Sequence doesn't match. Start new sequence with last key typed in.
    if {$seq eq "" && $kcode ne ""} {
      set keyseq ""
      seq_indicator
      if {$status(f)} {set kcode 42_$kcode}
      if {$status(g)} {set kcode 43_$kcode}
      dispatch_key $kcode
    }
    seq_indicator
  }

}

# ------------------------------------------------------------------------------
proc validateSB { wid cond ii len } {

  set rc [expr {[string is integer $ii] && [string length [string trim $ii]] <= $len}]
  if {$rc && $cond eq "focusout"} {
    if {[$wid get] < [$wid cget -from]} {
      set ::[$wid cget -textvariable] [$wid cget -from]
    } elseif {[$wid get] > [$wid cget -to]} {
      set ::[$wid cget -textvariable] [$wid cget -to]
    }
    set rc 0
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc maxLen { ii len } {

  return [expr {[string length [string trim $ii]] <= $len}]

}

# ------------------------------------------------------------------------------
proc Descriptor { idx } {

  global storage

  if {$idx in {"(i)" "I"}} {
    if {![isDescriptor $storage(I)]} { error "" "" {DIMMAT} }

    set md $storage(I)
  } else {
    set md "M$idx"
  }

  return $md

}

# ------------------------------------------------------------------------------
proc isDescriptor { val } {

  return [string equal [string index $val 0] "M"]

}

# ------------------------------------------------------------------------------
proc isLU { md } {

  global MAT

  set rc 0
  if {[llength $MAT($md\_LU)] > 0} {
    set rc 1
  }

  return $rc

}

# ------------------------------------------------------------------------------
proc browser_lookup {} {

  global APPDATA

  set bl {}
  foreach bw $APPDATA(browserlist) {
    set bwf [auto_execok $bw]
    if {[string length $bwf]} { lappend bl $bw $bwf }
  }

  return $bl

}

# ------------------------------------------------------------------------------
proc browser_select { wid browser } {

  global APPDATA

  if {$::tcl_platform(platform) eq "windows"} {
    set exetypes [list [list [mc app.extexe] {.exe}]]
  } else {
    set exetypes [list [list [mc app.extall] {*}]]
  }
  set nbw [tk_getOpenFile -parent .prefs -initialdir "[file dirname $browser]" \
    -title "$APPDATA(title): [mc pref.selbrowser]" \
    -filetypes $exetypes]

  if {[string length $nbw] > 0} {
    $wid configure -state normal
    $wid delete 0 end
    $wid insert 0 $nbw
    $wid xview [$wid index end]
    $wid configure -state disabled
  }

}

# ------------------------------------------------------------------------------
proc fontset_list {} {

  global FONTSET

  set rc {}
  foreach fs $FONTSET {
    if {[tk windowingsystem] == [lindex $fs 0]} { lappend rc $fs }
  }
  return $rc

}

# ------------------------------------------------------------------------------
proc fontset_cycle { dir } {

  global HP15 status curdisp

  if {[winfo exists .prefs]} {
    return
  }

  set fntlst [fontset_list]
  set fs [expr [lsearch -index 2 $fntlst $HP15(fsid)] $dir 1]
  if {$fs < 0} {
    set fs [expr [llength $fntlst]-1]
  } elseif {$fs >= [llength $fntlst]} {
    set fs 0
  }
  set HP15(fsid) [lindex [lindex $fntlst $fs] 2]
  gui_draw
  set_status NIL
  if {!$status(error)} {
    disp_refresh
  } else {
    set curdisp $curdisp
  }

}

# ------------------------------------------------------------------------------
proc fontset_apply { fsid } {

  global APPDATA LAYOUT HP15

  set fntlst [fontset_list]
  set fs [lsearch -inline -index 2 $fntlst $fsid]

  if {$fs eq ""} {
    tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
      -message [mc app.wrongfontset]
    set HP15(fsid) [dict get {x11 dv2 win32 ms2 aqua dv3} [tk windowingsystem]]
    set fs [lsearch -inline -index 2 $fntlst $HP15(fsid)]
  }

  foreach {attr val} [lindex $fs 3] {
    set LAYOUT($attr) $val
  }

}

# ------------------------------------------------------------------------------
proc lang_lookup {} {

  global APPDATA

  set ::LANGS [list [list "-" [mc gen.system]]]
  set locale_save [mclocale]
  foreach ll [glob -nocomplain "$APPDATA(basedir)/msgs/*.msg"] {
    set lc [file rootname [file tail $ll]]
    if {$lc ne "ROOT"} {
      mclocale $lc
      lappend ::LANGS [list $lc [mc pref.langname]]
    }
  }
  mclocale $locale_save

}

# ------------------------------------------------------------------------------
proc preferences_apply { andExit ww } {

  global APPDATA HP15 DM15 status curdisp
  global hp15tmp dm15tmp prdoctmp

  set prefs_ok true
  foreach vv {prgmmenubreak pause delay} {
    if {[string length [string trim $hp15tmp($vv)]] == 0} {
      tk_messageBox -type ok -icon error -default ok -title $APPDATA(title) \
        -message [mc pref.invalidvalue [mc pref.$vv]]
      set prefs_ok false
      break
    }
  }
  if {$prefs_ok} {
    set idx [lsearch -index 1 $::LANGS $::hp15tmplang]
    if {$idx < 0} {
      set hp15tmp(lang) "-"
    } else {
      set hp15tmp(lang) [lindex [lindex $::LANGS $idx] 0]
    }
    if {$hp15tmp(lang) eq "-" && $HP15(lang) != $hp15tmp(lang)} {
      set hp15tmp(lang) "+"
    }
    set hp15tmp(authorship) [string trim $hp15tmp(authorship)]

# Reset memory if memory has been shrinked or DM-15 mode has been switched off
    if {!$dm15tmp(dm15cc)} {set hp15tmp(totregs) 64}
    if {($hp15tmp(totregs) < $HP15(totregs)) ||
        (!$dm15tmp(dm15cc) && $DM15(dm15cc))} {
      array set HP15 [array get hp15tmp]
      mem_reset
    } else {
      array set HP15 [array get hp15tmp]
    }

# Transfer settings for modules
    array set DM15 [array get dm15tmp]
    array set ::prdoc::CONF [array get prdoctmp]

    preferences_apply_tcl
    if {$andExit} {destroy $ww}
    gui_draw
    raise .
    ::prdoc::ReDraw
    set_status NIL
    if {!$status(error)} {
      disp_refresh
    } else {
      set curdisp $curdisp
    }
  }

}

# ------------------------------------------------------------------------------
# Set Tcl/Tk variables or settings depending on HP-15C settings
proc preferences_apply_tcl {} {

  global APPDATA HP15 DM15 HP15_KEYS HP15_KEYS_DEF filehist

  set ::tcl_precision [expr $HP15(strictHP15) == 1 ? 10 : 0]
  set ::PI [expr acos(0)*2.0]

  set ml {"\u221Ax\u0305@" "\u221Ax@" e\u02E3 e^x \u02E3 ^x \u2B05 \u2190 \
    \u2B06 \u2191 \u2B07 \u2193 "RAN\u2009#" "RAN#"  \u2192\u2009R \u2192R \
    "x\u2009!" "x!" "P\u2009y,x" "Py,x" "x\u0305@" "x @" "C\u2009y,x" "Cy,x" \
    \u2212 - \u207B\u00B9 \u002D\u00B9}

  if {$HP15(extendedchars) == 0} {
    set HP15_KEYS {}
    foreach kk $HP15_KEYS_DEF {
      for {set ii 4} {$ii < 7} {incr ii} {
        lset kk $ii [string map $ml [lindex $kk $ii]]
      }
      lappend HP15_KEYS $kk
    }
  } else {
    set HP15_KEYS $HP15_KEYS_DEF
  }

  ::history::size filehist $HP15(histsize)

# Re-load language if user has overwritten system settings
  if {$HP15(lang) ne "-" && [lsearch [mcpreferences] $HP15(lang)] == -1} {
    if {$HP15(lang) eq "+"} {
      set HP15(lang) "-"
      mclocale $APPDATA(locale)
    } else {
      mclocale $HP15(lang)
    }
  }

# Update filetypes to new language
  set APPDATA(filetypes_in) [list [list [mc app.ext15c] ".15c"] \
    [list [mc app.exttxt] ".txt"]]
  set APPDATA(filetypes_out) [list [list [mc app.ext15c] ".15c"] \
    [list [mc app.exthtml] [list ".htm" ".html"]] [list [mc app.exttxt] ".txt"]]

# DM15 config
  if {[info exists DM15(timeout)]} {
    set ::DM15::COM(timeout) $DM15(timeout)
  }
  if {[info exists DM15(spdriver)]} {
    set ::DM15::COM(spdriver) $DM15(spdriver)
  }

  mbar_draw $::MENU([tk windowingsystem])
  mbar_show

  if {!$APPDATA(tkpath)} {
    set HP15(usetkpath) 0
  } elseif {$APPDATA(tkpath) && !$APPDATA(hp15cfont)} {
    set HP15(usetkpath) 1
  }

}

# ------------------------------------------------------------------------------
proc set_widget_state { wid sts } {

  set chlst [winfo children $wid]
# WA: ttk::combobox has child widgets that do not support option 'state'
  if {[winfo class $wid] eq "TCombobox"} { set chlst {} }

  if {[llength $chlst] > 0} {
    foreach ch $chlst {
      set_widget_state $ch $sts
    }
  } else {
    if {$sts} {
      $wid state !disabled
    } else {
      $wid state disabled
    }
  }

}

# ------------------------------------------------------------------------------
proc set_tag_colour { wid col } {

  upvar $col icol

  set ncol [tk_chooseColor -initialcolor $icol -parent $wid \
    -title "[mc pdocu.hilitags]: [mc gen.colour]"]
  if {$ncol ne ""} {
    $wid configure -foreground $ncol
    set icol $ncol
  }

}

# ------------------------------------------------------------------------------
if {[namespace exists ::tk::mac::]} {
  proc ::tk::mac::ShowPreferences {} {
    preferences
  }
}

# ------------------------------------------------------------------------------
proc preferences {} {

  global APPDATA HP15 DM15 hp15tmp dm15tmp prdoctmp

  array set hp15tmp [array get HP15]
  array set dm15tmp [array get DM15]
  array set prdoctmp [array get ::prdoc::CONF]

  if {[winfo exists .prefs]} {
    wm deiconify .prefs
  } else {

    toplevel .prefs
    wm attributes .prefs -alpha 0.0

    ttk::notebook .prefs.nb -padding [list 5 5 5 5]

# Simulator settings
    set fpo .prefs.nb.behave
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc pref.frm_simulator] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 0 -image [list $APPDATA(PrefIconSimulator)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo

    ttk::checkbutton $fpo.behaviour -text [mc pref.strictHP15] \
      -variable hp15tmp(strictHP15)

    ttk::frame $fpo.pause
    ttk::label $fpo.pause.label -text "[mc pref.pause] \[ms\]" -anchor w
    ttk::spinbox $fpo.pause.sb -width 4 -justify right -from 0 -to 2000 \
      -increment 100 -textvariable ::hp15tmp(pause) -validate all \
      -validatecommand "validateSB %W %V %P 4"
    grid $fpo.pause.label -row 0 -column 0 -sticky nw
    grid $fpo.pause.sb -row 0 -column 1 -sticky e
    grid columnconfigure $fpo.pause 1 -weight 2

    ttk::frame $fpo.delay
    ttk::label $fpo.delay.label -text "[mc pref.delay] \[ms\]" -anchor w
    ttk::spinbox $fpo.delay.sb -width 3 -justify right -from 0 -to 999 \
      -increment 1 -textvariable ::hp15tmp(delay) -validate all \
      -validatecommand "validateSB %W %V %P 3"
    grid $fpo.delay.label -row 0 -column 0 -sticky nw
    grid $fpo.delay.sb -row 0 -column 1 -sticky e
    grid columnconfigure $fpo.delay 1 -weight 2

    ttk::checkbutton $fpo.secondaryclick -text [mc pref.secondary.click] \
      -variable hp15tmp(secondaryclick) \
      -command "set_widget_state $fpo.secondaryhilight \$::hp15tmp(secondaryclick)"
    ttk::checkbutton $fpo.secondaryhilight -text [mc pref.secondary.hilight] \
      -variable hp15tmp(secondaryhilight)
    set_widget_state $fpo.secondaryhilight $::hp15tmp(secondaryclick)
    ttk::checkbutton $fpo.seqindicator -text [mc pref.seqindicator] \
      -variable hp15tmp(seqindicator)
    ttk::checkbutton $fpo.clpbrdc -text [mc pref.clpbrdc] \
      -variable hp15tmp(clpbrdc)
    ttk::checkbutton $fpo.saveonexit -text [mc pref.saveonexit] \
      -variable hp15tmp(saveonexit)
    ttk::checkbutton $fpo.clpbrdprgm -text [mc pref.clpbrdprgm] \
      -variable hp15tmp(clpbrdprgm)
    ttk::checkbutton $fpo.savewinpos -text [mc pref.savewinpos] \
      -variable hp15tmp(savewinpos)

    grid $fpo.behaviour -row 0 -column 0 -sticky nw
    grid $fpo.pause -row 1 -column 0 -pady 2 -sticky we
    grid $fpo.delay -row 2 -column 0 -pady 2 -sticky we
    grid $fpo.secondaryclick -row 3 -column 0 -sticky nw
    grid $fpo.secondaryhilight -row 4 -column 0 -padx 20 -sticky nw
    grid $fpo.seqindicator -row 5 -column 0 -sticky nw
    grid $fpo.saveonexit -row 6 -column 0 -sticky nw
    grid $fpo.clpbrdc -row 7 -column 0 -stick nw
    grid $fpo.clpbrdprgm -row 8 -column 0 -stick nw
    grid $fpo.savewinpos -row 9 -column 0 -stick nw
    grid $fpo -row 0 -column 0 -padx 10 -pady 10 -sticky nwse

# System integration and representation
    set fpo .prefs.nb.hp15
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc gen.menus] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 1 -image [list $APPDATA(PrefIconSystem)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo

    ttk::checkbutton $fpo.showmenu -text [mc pref.showmenu] \
      -variable hp15tmp(showmenu)
    ttk::checkbutton $fpo.osxmenus -text [mc pref.osxmenus] \
      -variable hp15tmp(osxmenus)
    if {[tk windowingsystem] eq "aqua"} {
      $fpo.showmenu configure -state disabled
      set hp15tmp(showmenu) 1
    } else {
      $fpo.osxmenus configure -state disabled
    }

    ttk::frame $fpo.hist
    ttk::label $fpo.hist.label -text [mc pref.histsize] -anchor w
    ttk::spinbox $fpo.hist.sb -width 2 -justify right -from 10 -to 30 \
      -increment 1 -textvariable ::hp15tmp(histsize) -validate all \
      -validatecommand "validateSB %W %V %P 2"
    ttk::checkbutton $fpo.hist.fullpath -text [mc pref.histfullpath] \
      -variable hp15tmp(histfullpath)
    grid $fpo.hist.label -row 0 -column 0 -sticky nw
    grid $fpo.hist.sb -row 0 -column 1 -sticky e
    grid $fpo.hist.fullpath -row 1 -sticky nw -padx 20 -columnspan 2
    grid columnconfigure $fpo.hist 1 -weight 2

    ttk::checkbutton $fpo.mnemonics -text [mc pref.mnemonics] \
      -variable hp15tmp(mnemonics)
    ttk::checkbutton $fpo.prgmcoloured -text [mc pref.prgmcoloured] \
      -variable hp15tmp(prgmcoloured)

    ttk::frame $fpo.prgm
    ttk::label $fpo.prgm.label -text [mc pref.prgmmenubreak] -anchor w
    ttk::spinbox $fpo.prgm.sb -width 2 -justify right -from 10 -to 50 \
      -increment 1 -textvariable ::hp15tmp(prgmmenubreak) -validate all \
      -validatecommand "validateSB %W %V %P 2"
    grid $fpo.prgm.label -row 0 -column 0 -sticky nw
    grid $fpo.prgm.sb -row 0 -column 1 -sticky e
    grid columnconfigure $fpo.prgm 1 -weight 2

    ttk::checkbutton $fpo.breakstomenu -text [mc pref.breakstomenu] \
      -variable hp15tmp(breakstomenu)
    ttk::checkbutton $fpo.stomenudesc -text [mc pref.stomenudesc] \
      -variable hp15tmp(stomenudesc)
    ttk::checkbutton $fpo.dotmarks -text [mc pref.dotmarks] \
      -variable hp15tmp(dotmarks)
    ttk::checkbutton $fpo.sortgsb -text [mc pref.sortgsb] \
      -variable hp15tmp(sortgsb)

    grid $fpo.showmenu -row 0 -column 0 -stick nw
    grid $fpo.osxmenus -row 1 -column 0 -sticky nw
    grid $fpo.hist -row 2 -column 0 -sticky ew
    grid $fpo.mnemonics -row 3 -column 0 -stick nw
    grid $fpo.prgmcoloured  -row 4 -column 0 -stick nw
    grid $fpo.prgm -row 5 -column 0 -pady 2 -stick ew
    grid $fpo.dotmarks -row 6 -column 0 -stick nw
    grid $fpo.breakstomenu -row 7 -column 0 -stick nw
    grid $fpo.stomenudesc -row 8 -column 0 -stick nw
    grid $fpo.sortgsb -row 9 -column 0 -stick nw

# Separator
    ttk::separator $fpo.sep -orient vertical
    grid $fpo.sep -row 0 -column 1 -rowspan 10 -padx 10 -sticky ns

# Matrices
    ttk::frame $fpo.fms
    ttk::label $fpo.fms.notation -text "[mc pref.matrix.notation] "
    ttk::radiobutton $fpo.fms.rowcol -text [mc pref.matrix.rowcol] \
      -variable hp15tmp(matstyle) -value rowcol
    ttk::radiobutton $fpo.fms.cell -text [mc pref.matrix.cell] \
      -variable hp15tmp(matstyle) -value cell
    ttk::label $fpo.fms.matseplbl -text "[mc pref.matrix.separator] "
    ttk::radiobutton $fpo.fms.semicolon -text [mc gen.semicolon] \
      -variable hp15tmp(matseparator) -value semicolon
    ttk::radiobutton $fpo.fms.tab -text [mc gen.tab] \
      -variable hp15tmp(matseparator) -value tab
    ttk::radiobutton $fpo.fms.comma -text [mc gen.comma] \
      -variable hp15tmp(matseparator) -value comma

    grid $fpo.fms.notation -row 0 -column 0 -columnspan 2 -sticky nw
    grid $fpo.fms.rowcol -row 1 -column 1 -sticky nw
    grid $fpo.fms.cell -row 2 -column 1 -sticky nw
    grid $fpo.fms.matseplbl -row 3 -column 0 -columnspan 2 -sticky nw
    grid $fpo.fms.semicolon -row 4 -column 1 -sticky nw
    grid $fpo.fms.tab -row 5 -column 1 -sticky nw
    grid $fpo.fms.comma -row 6 -column 1 -sticky nw
    grid columnconfigure $fpo.fms 0 -minsize 20

    ttk::checkbutton $fpo.matcascade -text [mc pref.matrix.cascade] \
      -variable hp15tmp(matcascade)

    grid $fpo.fms -row 0 -column 2 -columnspan 2 -rowspan 6 -sticky nw
    grid $fpo.matcascade -row 6 -column 2 -stick nw

# Language
    ttk::frame $fpo.lang
    ttk::label $fpo.lang.label -text [mc pref.language] -anchor w
    lang_lookup
    foreach ll $::LANGS {
      lappend langlist [lindex $ll 1]
      if {[lindex $ll 0] == $HP15(lang)} {
        set curlang [lindex $ll 1]
      }
    }
    if {![info exists curlang]} {set curlang "System"}
    ttk::combobox $fpo.lang.cb -state readonly -textvariable ::hp15tmplang \
      -values $langlist
    $fpo.lang.cb set $curlang
    grid $fpo.lang.label -row 0 -column 0 -sticky nw
    grid $fpo.lang.cb -row 0 -column 1 -sticky e
    grid columnconfigure $fpo.lang 1 -weight 2
    grid $fpo.lang -row 9 -column 2 -pady 2 -stick we

    grid $fpo -row 0 -column 0 -padx 10 -pady 10 -sticky nw
    grid columnconfigure $fpo 1 -weight 1

# File format and layout
    set fpo .prefs.nb.files
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc gen.files] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 2 -image [list $APPDATA(PrefIconFiles)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo

# Files tab
    set fpf $fpo.files
    ttk::frame $fpf

# 15C File format
    set fpe $fpo.ext15c
    ttk::frame $fpe
    ttk::label $fpe.lbl15c -text "[mc app.ext15c]:"
    ttk::checkbutton $fpe.prgmstounicode -text [mc pref.prgmstounicode] \
      -variable hp15tmp(prgmstounicode)
    grid $fpe.lbl15c -row 0 -column 0 -columnspan 2 -sticky nw
    grid $fpe.prgmstounicode -row 1 -column 0 -padx 10 -columnspan 2 -sticky nw
    grid $fpe -row 0 -column 0 -sticky nw

# HTML File format
    set fph $fpo.html
    ttk::frame $fph
    ttk::label $fph.lblhtml -text "[mc app.exthtml]:"
    ttk::checkbutton $fph.html_en -text [mc pref.html_en] \
      -variable hp15tmp(html_en)
    ttk::checkbutton $fph.html_indent -text [mc pref.html_indent] \
      -variable hp15tmp(html_indent)
    ttk::checkbutton $fph.docuwarn -text [mc pref.docuwarn] \
      -variable hp15tmp(docuwarn)
    ttk::checkbutton $fph.html_1column -text [mc pref.html_1column] \
      -variable hp15tmp(html_1column)
    ttk::checkbutton $fph.html_bwkeys -text [mc pref.html_bwkeys] \
      -variable hp15tmp(html_bwkeys)

    grid $fph.lblhtml -row 3 -column 0 -sticky nw
    grid $fph.html_en -row 4 -column 0 -padx 10 -sticky nw
    grid $fph.html_indent -row 5 -column 0 -padx 10 -sticky nw
    grid $fph.docuwarn -row 6 -column 0 -padx 10 -sticky nw
    grid $fph.html_1column -row 7 -column 0 -padx 10 -sticky nw
    grid $fph.html_bwkeys -row 8 -column 0 -padx 10 -sticky nw
    grid $fph -row 2 -column 0 -sticky nw

# Separator
    ttk::separator $fpo.sep -orient vertical
    grid $fpo.sep -row 0 -column 1 -rowspan 3 -sticky ns

# Program description handling
    ttk::label $fpf.lbldesc -text "[mc pdocu.description]:"
    ttk::checkbutton $fpf.docuonload -text "[mc pref.docuonload]" \
      -variable hp15tmp(docuonload)
    ttk::checkbutton $fpf.autopreview -text "[mc pref.autopreview]" \
      -variable prdoctmp(autopreview)
    ttk::checkbutton $fpf.unicodesyms -text "[mc pref.unicodesyms]" \
      -variable prdoctmp(unicodesyms)

    set ftb $fpf.tbs
    ttk::frame $ftb
    ttk::label $ftb.toolbarstyle -text "[mc pref.toolbarstyle]"
    ttk::radiobutton $ftb.tbicons -text [mc gen.icons] \
      -variable prdoctmp(toolbarstyle) -value icons
    ttk::radiobutton $ftb.tbtext -text [mc gen.text] \
      -variable prdoctmp(toolbarstyle) -value text
    grid $ftb.toolbarstyle -row 0 -column 0 -sticky nw
    grid $ftb.tbicons -row 0 -column 1 -sticky nw
    grid $ftb.tbtext -row 0 -column 2 -sticky nw

    ttk::checkbutton $fpf.tagmenuicons -text "[mc pref.tagmenu.icons]" \
      -variable prdoctmp(tagmenuicons)

    set fph $fpf.hlt
    ttk::frame $fph
    set fpc $fph.col
    ttk::checkbutton $fph.hltags -text "[mc pdocu.hilitags]" \
      -variable prdoctmp(taghighlight) \
      -command "set_widget_state {*}$fpc \$::prdoctmp(taghighlight)"
    ttk::frame $fpc
    ttk::button $fpc.btncol -text "[mc gen.colour]\u2026" \
      -command "set_tag_colour $fpc.colour prdoctmp(tagcolour)"
    ttk::label $fpc.colour -text "\u2588\u2588" -foreground $prdoctmp(tagcolour)
    ttk::checkbutton $fpc.tagbold -text "[mc gen.bold]" -variable prdoctmp(tagbold)
    grid $fph.hltags -row 0 -column 0 -sticky nw
    grid $fpc.btncol -row 0 -column 1 -padx 5 -sticky nw
    grid $fpc.colour -row 0 -column 2 -sticky nw
    grid $fpc.tagbold -row 0 -column 3 -padx 5 -sticky nw
    grid $fpc -row 0 -column 1 -sticky nw
    set_widget_state $fpc $::prdoctmp(taghighlight)

    set fpm $fpf.mkc
    ttk::frame $fpm
    ttk::label $fpm.markcolour -text [mc pdocu.markcolour]
    ttk::button $fpm.btncol -text "[mc gen.colour]\u2026" \
      -command "set_tag_colour $fpm.colour prdoctmp(markcolour)"
    ttk::label $fpm.colour -text "\u2588\u2588" -foreground $prdoctmp(markcolour)
    grid $fpm.markcolour -row 0 -column 0 -sticky nw
    grid $fpm.btncol -row 0 -column 1 -padx 5 -sticky nw
    grid $fpm.colour -row 0 -column 2 -sticky nw

    ttk::checkbutton $fpf.restab -text [mc pdocu.restab] \
      -variable prdoctmp(ShowResTab)

    grid $fpf.lbldesc -row 0 -column 0 -columnspan 2 -sticky nw
    grid $fpf.docuonload -row 1 -column 1 -sticky nw
    grid $fpf.autopreview -row 2 -column 1 -sticky nw
    grid $fpf.unicodesyms -row 3 -column 1 -sticky nw
    grid $fpf.tbs -row 4 -column 1 -sticky nw
    grid $fpf.hlt -row 5 -column 1 -sticky nw
    grid $fpf.mkc -row 6 -column 1 -sticky nw
    grid $fpf.restab -row 7 -column 1 -sticky nw
    grid $fpf -row 0 -column 3 -rowspan 3 -sticky nw
    grid columnconfigure $fpf 0 -minsize 10

    grid columnconfigure $fpo 2 -minsize 10

# Authorship
    set fpa $fpo.authorship
    ttk::frame $fpa
    ttk::label $fpa.lbauthorship -text "[mc pdocu.authorship]"
    ttk::entry $fpa.authorshipval -textvariable hp15tmp(authorship) \
      -validate key -validatecommand "maxLen %P 80"

    grid $fpa.lbauthorship -row 0 -column 0 -padx 10 -sticky nw -columnspan 2
    grid $fpa.authorshipval -row 1 -column 1 -sticky we -columnspan 2
    grid columnconfigure $fpa 0 -minsize 12
    grid columnconfigure $fpa 1 -weight 1
    grid $fpa -row 3 -column 0 -pady 5 -sticky we -columnspan 4

    grid rowconfigure $fpo 1 -minsize 10
    grid $fpo -row 0 -column 0 -padx 10 -pady 10 -stick nwse

# DM-15 support
    set fpo .prefs.nb.dm15cc
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc menu.dm15cc] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 3 -image [list $APPDATA(PrefIconDM15CC)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo
    ttk::checkbutton $fpo.dm15cc -text [mc pref.dm15cc] -variable dm15tmp(dm15cc) \
      -command "set_widget_state {*}$fpo.param \$::dm15tmp(dm15cc)"
    ttk::frame $fpo.param_pad -width 15

# DM-15C Parameter
    set fpo $fpo.param
    ttk::frame $fpo

# DM15 config
    set fco $fpo.conf
    ttk::frame $fco

    ttk::frame $fco.sp
    ttk::label $fco.sp.label -text [mc pref.dm15cc.port] -anchor w
    ttk::radiobutton $fco.sp.slabs -text [mc pref.spdriver.slabs] \
      -variable dm15tmp(spdriver) -value slabs
    ttk::radiobutton $fco.sp.native -text [mc pref.spdriver.native] \
      -variable dm15tmp(spdriver) -value native
    ttk::spinbox $fco.sp.com -width 3 -justify right -from 0 -to 255 \
      -increment 1 -textvariable ::dm15tmp(dm15cc_port) -validate all \
      -validatecommand "validateSB %W %V %P 3"
    if {[info exists DM15(dm15cc_port)]} {
      $fco.sp.com set $DM15(dm15cc_port)
    } else {
      $fco.sp.com set ""
    }

    ttk::label $fco.tolabel -text "[mc pref.dm15cc.timeout] \[s\]"
    ttk::combobox $fco.tocb -justify right -width 1 -state readonly \
      -textvariable dm15tmp(timeout) -values [list 1 2 3 4 5]

    ttk::label $fco.maxregs -text [mc pref.maxregs]
    ttk::radiobutton $fco.reg64 -text "64" -variable hp15tmp(totregs) -value 64
    ttk::radiobutton $fco.reg128 -text "128" -variable hp15tmp(totregs) -value 128
    ttk::radiobutton $fco.reg229 -text "229" -variable hp15tmp(totregs) -value 229
    ttk::label $fco.mem80info -text [mc pref.regreset] -wraplength 220

    ttk::separator $fco.sep -orient vertical

    if {$::tcl_platform(os) eq "Darwin"} {
      if {[package vcompare $::tcl_platform(osVersion) 20.0.0] >= 0} {
        grid $fco.sp.label -row 0 -column 0 -columnspan 3 -sticky nw
        grid $fco.sp.native -row 1 -column 0 -padx 20 -stick nw
        grid $fco.sp.com -row 1 -column 1 -sticky ne
        grid $fco.sp.slabs -row 2 -column 0 -padx 20 -stick nw
        grid rowconfigure $fco.sp 3 -minsize 6
      } else {
        set dm15tmp(spdriver) slabs
      }
    } else {
      grid $fco.sp.label -row 0 -column 0 -sticky nw
      grid $fco.sp.com -row 0 -column 1 -sticky ne
      grid rowconfigure $fco.sp 1 -minsize 2
    }
    grid columnconfigure $fco.sp 0 -weight 2
    grid $fco.sp -row 0 -column 0 -columnspan 2 -sticky nwse

    grid $fco.tolabel -row 1 -column 0 -sticky nw
    grid $fco.tocb -row 1 -column 1 -sticky ne

    grid rowconfigure $fco 2 -minsize 2

    grid $fco.maxregs -row 3 -column 0 -sticky nw
    grid $fco.reg64 -row 4 -column 0 -padx 20 -sticky nw
    grid $fco.reg128 -row 5 -column 0 -padx 20 -sticky nw
    grid $fco.reg229 -row 6 -column 0 -padx 20 -sticky nw
    grid $fco.mem80info -row 7 -column 0 -columnspan 2 -sticky nw
    grid $fco.sep -row 0 -column 2 -rowspan 8 -padx 10 -sticky ns

# Read-/Write options

    set fex $fpo.exchg
    ttk::frame $fex
    ttk::label $fex.rw_info -text "[mc pref.dm15cc.transmitted]" -anchor w
    ttk::label $fex.read -text "[mc gen.read]" -anchor w
    ttk::label $fex.write -text "[mc gen.write]" -anchor w

    ttk::label $fex.stack -text [mc gen.stack]
    ttk::label $fex.sto -text [mc gen.regs]
    ttk::label $fex.mat -text [mc gen.matrices]
    ttk::label $fex.flags -text [mc gen.flags]
    ttk::label $fex.prgm -text [mc gen.program]

    ttk::checkbutton $fex.r_prgm -variable dm15tmp(r_prgm)
    ttk::checkbutton $fex.r_sto -variable dm15tmp(r_sto)
    ttk::checkbutton $fex.r_mat -variable dm15tmp(r_mat)
    ttk::checkbutton $fex.r_stack -variable dm15tmp(r_stack)
    ttk::checkbutton $fex.r_flags -variable dm15tmp(r_flags)

    ttk::checkbutton $fex.w_prgm -variable dm15tmp(w_prgm)
    ttk::checkbutton $fex.w_sto -variable dm15tmp(w_sto)
    ttk::checkbutton $fex.w_mat -variable dm15tmp(w_mat)
    ttk::checkbutton $fex.w_stack -variable dm15tmp(w_stack)
    ttk::checkbutton $fex.w_flags -variable dm15tmp(w_flags)

    ttk::checkbutton $fex.interactive -text [mc dm15cc.interactive] \
      -variable dm15tmp(interactive)

    grid columnconfigure $fex 0 -minsize 20 -weight 0

    grid $fex.rw_info -row 0 -column 0 -columnspan 2 -sticky nw
    grid $fex.prgm -row 1 -column 1 -sticky w
    grid $fex.sto -row 2 -column 1 -sticky w
    grid $fex.mat -row 3 -column 1 -sticky w
    grid $fex.stack -row 4 -column 1 -sticky w
    grid $fex.flags -row 5 -column 1 -sticky w

    grid $fex.read -row 0 -column 2 -sticky w
    grid $fex.r_prgm -row 1 -column 2 -padx 5
    grid $fex.r_sto -row 2 -column 2 -padx 5
    grid $fex.r_mat -row 3 -column 2 -padx 5
    grid $fex.r_stack -row 4 -column 2 -padx 5
    grid $fex.r_flags -row 5 -column 2 -padx 5

    grid $fex.write -row 0 -column 3 -sticky w
    grid $fex.w_prgm -row 1 -column 3 -padx 5
    grid $fex.w_sto -row 2 -column 3 -padx 5
    grid $fex.w_mat -row 3 -column 3 -padx 5
    grid $fex.w_stack -row 4 -column 3 -padx 5
    grid $fex.w_flags -row 5 -column 3 -padx 5

    grid $fex.interactive -row 6 -column 0 -pady 5 -stick nw -columnspan 4

# Grid DM-15 notebook tab
    grid $fpo.conf -row 0 -column 0 -pady 5 -sticky nw
    grid $fpo.exchg -row 0 -column 2 -pady 5 -sticky nw

    set fpo .prefs.nb.dm15cc.f
    grid $fpo.dm15cc -row 0 -column 0 -columnspan 2 -padx 5 -sticky nw
    grid $fpo.param_pad -row 1 -column 0 -padx 5
    grid $fpo.param -row 1 -column 1 -sticky nw
    set_widget_state $fpo.param $::dm15tmp(dm15cc)
    grid $fpo -row 0 -column 0 -padx 5 -pady 10 -sticky nw

# Font settings
    set fpo .prefs.nb.fontset
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc pref.frm_fontset] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 4 -image [list $APPDATA(PrefIconFonts)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo

    ttk::label $fpo.info -anchor nw -justify left \
      -text [mc pref.fontsets $::tcl_platform(os) [expr round([tk scaling]*72)]]

    ttk::frame $fpo.fs
    set rr 0
    foreach fs [fontset_list] {
      set fsid [lindex $fs 2]
      ttk::radiobutton $fpo.fs.$fsid -text "[lindex $fs 1]" -value $fsid \
        -variable hp15tmp(fsid)
      grid $fpo.fs.$fsid -row $rr -column 0 -sticky nw
      incr rr
    }

    ttk::checkbutton $fpo.extendedchars -text [mc pref.extendedchars] \
      -variable hp15tmp(extendedchars)

    ttk::checkbutton $fpo.tkp -text [mc pref.tkpath] -variable hp15tmp(usetkpath)
# Only if both TkPath and the HP-15C Font are available the user may choose
    if {!$APPDATA(tkpath) || !$APPDATA(hp15cfont)} {
      $fpo.tkp configure -state disabled
    }

    grid $fpo.info -row 0 -column 0 -sticky nw
    grid $fpo.fs -row 1 -column 0 -padx 20 -pady 5 -sticky nw
    grid $fpo.extendedchars -row 2 -column 0 -sticky nw
    grid $fpo.tkp -row 3 -column 0 -sticky nw
    grid $fpo -row 0 -column 0 -padx 10 -pady 10 -sticky nw

# Browser settings
    set fpo .prefs.nb.browser
    ttk::frame $fpo
    grid columnconfigure $fpo 0 -weight 1
    .prefs.nb add $fpo -text " [mc pref.browser] "
    if {$APPDATA(PrefIcons)} {
      .prefs.nb tab 5 -image [list $APPDATA(PrefIconHelp)] -compound top
    }

    set fpo $fpo.f
    ttk::frame $fpo
    ttk::frame $fpo.bw
    set rr 0
    foreach {bw bwf} [browser_lookup] {
      ttk::radiobutton $fpo.bw.$bw -text $bw -value $bwf -variable hp15tmp(browser)
      grid $fpo.bw.$bw -row $rr -column 0 -sticky nw
      incr rr
    }

    ttk::button $fpo.sel -text [mc pref.browse] \
      -command "browser_select {$fpo.entry} {$hp15tmp(browser)}"
    ttk::entry $fpo.entry -justify left -textvariable hp15tmp(browser)

    grid $fpo.bw -row 0 -column 0 -sticky nw
    grid $fpo.entry -row 1 -column 0 -pady 5 -sticky we
    grid $fpo.sel -row 2 -column 0 -sticky e
    grid $fpo -row 0 -column 0 -padx 10 -pady 10 -sticky nswe
    grid columnconfigure $fpo 0 -weight 2

# Grid the notebook
    grid .prefs.nb -row 0 -column 0 -sticky nwse

# Button frame
    set fbtn .prefs.btn
    ttk::frame $fbtn -relief flat -borderwidth 5
    ttk::button $fbtn.ok -text [mc gen.ok] -default active \
      -command "preferences_apply true .prefs"
    ttk::button $fbtn.apply -text [mc gen.apply] \
      -command "preferences_apply false .prefs"
    ttk::button $fbtn.cancel -text [mc gen.cancel] -command "destroy .prefs"

    grid $fbtn.ok -row 0 -column 0 -padx 5 -pady 5 -sticky e
    grid $fbtn.cancel -row 0 -column 1 -padx 5 -pady 5 -sticky e
    grid $fbtn.apply -row 0 -column 2 -padx 5 -pady 5 -sticky e
    grid $fbtn -row 1 -column 0 -sticky nsew
    grid columnconfigure $fbtn 0 -weight 2

    bind .prefs <Return> "$fbtn.ok invoke"
    bind .prefs <Escape> "$fbtn.cancel invoke"

    wm title .prefs [mc pref.title $APPDATA(title)]
    wm transient .prefs .
    wm resizable .prefs false false
    update

# Tcl/Tk 8.6.7 fixed the option to adjust the tab width
    if {[package vcompare [info patchlevel] 8.6.7] >= 0} {
      ttk::style configure TNotebook \
        -mintabwidth [expr [winfo width .prefs]/[llength [winfo children .prefs.nb]]-3]
    }

# WA-Win 10: Spinbox widget is without padding on the right side
    if {[tk windowingsystem] eq "win32" && $::tcl_platform(osVersion) > 6.0} {
      ttk::style configure TSpinbox -padding {0 0 3 0}
    }

    set px [expr [winfo screenwidth .prefs]/2 - [winfo width .prefs]/2]
    set py [expr [winfo screenheight .prefs]/2 - [winfo height .prefs]/2]
    wm geometry .prefs +$px+$py
    update
    wm attributes .prefs -alpha 1.0

    raise .prefs
    focus .prefs

  }

}

# ------------------------------------------------------------------------------
proc exit {} {

  global HP15 status

  if {$HP15(saveonexit)} {
    if {![::prdoc::Act no]} { return }
    if {$status(error)} {func_clx}
    mem_save
    hist_save
  }
  ::exit_org

}

# ------------------------------------------------------------------------------
proc about {} {

  global APPDATA LAYOUT

  set disclaimer \
    "This program is free software; you can redistribute it and/or modify it\
    under the terms of the GNU General Public License as published by the\
    Free Software Foundation; either version 3 of the License, or (at your option)\
    any later version.\n\nThis program is distributed in the hope that it will\
    be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of\
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General\
    Public License for more details.\n\nYou should have received a copy of the\
    GNU General Public License along with this program; if not, see "

  if {[tk windowingsystem] eq "aqua"} {
    set awid 54
  } else {
    set awid 60
  }
  set sepline "[string repeat "\u2013" $awid]\n"

  if {[winfo exists .about]} {destroy .about}

  toplevel .about
  wm attributes .about -alpha 0.0

  set tx0 30
  set ty0 20

  canvas .about.cv -highlightthickness 0
  foreach yy {0 180 360} {
    .about.cv create image 0 $yy -image $APPDATA(dispframe) -anchor nw
  }

  text .about.text -height 24 -width $awid -relief flat -highlightthickness 0 \
    -borderwidth 0 -background $LAYOUT(display) -font FnAbout -cursor arrow
  .about.cv create window $tx0 $ty0 -window .about.text -anchor nw

  .about.text insert end "\n" warranty
  .about.text insert end $APPDATA(title) app
  .about.text insert end \
    "\n\n[mc about.line1]\n\n $APPDATA(copyright)\n[mc about.line2] " about
  .about.text insert end $APPDATA(homepage) {about url homepage}

  set text "\n\n[mc about.line3] $APPDATA(SerialNo)\n[mc about.line4] "
  append text "$::tcl_platform(os) $::tcl_platform(osVersion) "
  append text "($::tcl_platform(machine) $::tcl_platform(platform)) "
  if {![info exists ::starkit::topdir]} {
    set bits ""
    if {[info exists ::tcl_platform(wordSize)]} {
      set bits ", [expr $::tcl_platform(wordSize)*8]bit"
    }
    if {$::tcl_platform(machine) eq "amd64"} {
      set bits ", 64bit"
    }
    append text \
      "\nTcl/Tk: [file tail [info nameofexecutable]] (Version $::tcl_patchLevel$bits)"
  }

  .about.text insert end $text about
  .about.text insert end "\n$sepline" about
  .about.text insert end $disclaimer warranty \
    "https://www.gnu.org/licenses" {warranty url gpl}
  .about.text insert end "\n$sepline" about
  .about.text insert end "[mc about.hpdisclaimer]" warranty

# Finally configure text tags
  .about.text tag configure app -font FnApp -justify center
  .about.text tag configure about -font FnAbout -justify center
  .about.text tag configure url -foreground mediumblue
  .about.text tag configure warranty -font FnWarranty -justify left -wrap word
  .about.text tag bind url <Enter> ".about.text configure -cursor hand2"
  .about.text tag bind url <Leave> ".about.text configure -cursor arrow"

  .about.text configure -state disabled

  grid .about.cv -row 0 -column 0
  update

  set cvw [expr  [winfo width .about.text]+2*$tx0]
  set cvh [winfo width .about.text]
  .about.cv configure -width $cvw -height $cvh

  roundRect .about.cv 15 10 [expr $cvw-10] [expr $cvh-10] 5 -outline #9C9E9E \
    -fill #9C9E9E
  roundRect .about.cv 17 11 [expr $cvw-10] [expr $cvh-10] 5 -outline #F5F8F8 \
    -fill #F5F8F8
  roundRect .about.cv 17 11 [expr $cvw-12] [expr $cvh-11] 5 \
    -outline $LAYOUT(display_inner_frame) -fill $LAYOUT(display_inner_frame)
  roundRect .about.cv 27 13 [expr $cvw-22] [expr $cvh-14] 5 \
     -outline #EFF4F3 -fill  $LAYOUT(display)
  roundRect .about.cv 26 12 [expr $cvw-23] [expr $cvh-15] 5 \
    -outline #69695A -fill $LAYOUT(display)
  roundRect .about.cv 27 13 [expr $cvw-23] [expr $cvh-15] 5 \
    -outline $LAYOUT(display) -fill $LAYOUT(display)

  ttk::frame .about.bfrm -relief raised
  ttk::button .about.bfrm.off -text [mc gen.ok] -command "destroy_modal .about"

  grid .about.bfrm.off -row 0 -column 0 -padx 15 -pady 7
  grid .about.bfrm -row 1 -column 0 -sticky we
  grid columnconfigure .about.bfrm 0 -weight 2

  .about.text tag bind homepage "<Button-1>" "url_open $APPDATA(homepage)"
  .about.text tag bind gpl "<Button-1>" "url_open https://www.gnu.org/licenses"

  wm title .about [mc about.title $APPDATA(title)]
  wm transient .about .
  wm deiconify .about
  wm resizable .about false false

  update
  set px [expr [winfo screenwidth .about]/2 - [winfo width .about]/2]
  set py [expr [winfo screenheight .about]/2 - [winfo height .about]/2]
  wm geometry .about +$px+$py

  bind .about <Return> "destroy_modal %W"
  bind .about <Escape> "destroy_modal %W"
  wm protocol .about WM_DELETE_WINDOW "destroy_modal .about"

  bind .about <$APPDATA(control)-Shift-K> "console show"

  raise .about
  grab .about
  focus .about
  wm attributes .about -alpha 1.0

}

# ------------------------------------------------------------------------------
proc seq_pending { {mode ""} }  {

  global keyseq pendingseq

  if {$mode == true} {
    set pendingseq $keyseq
  } elseif {$mode == false} {
    set pendingseq ""
  }

  return $pendingseq

}

# ------------------------------------------------------------------------------
proc seq_indicator {} {

  global HP15 keyseq prgstat

  if {$HP15(seqindicator)} {
    if {$prgstat(running) || $keyseq in {"" 42 43}} {
      set ind ""
    } else {
      set ind "\u25FC"
    }
    if {[winfo exists .gui]} {
      .gui itemconfigure sseqindicator -text $ind
    }
  }

}

# ------------------------------------------------------------------------------
proc key_f { ev } {

  global status prgstat

  if {$ev == 0} {
    if {!$status(error) && !$prgstat(running)} {
      set_status f
    }
    key_press btn_42 42
  } else {
    key_release btn_42
  }

}

# ------------------------------------------------------------------------------
proc key_g { ev } {

  global status prgstat

  if {$ev == 0} {
    if {!$status(error) && !$prgstat(running)} {
      set_status g
    }
    key_press btn_43 43
  } else {
    key_release btn_43
  }

}

# ------------------------------------------------------------------------------
proc key_press { btn code } {

  global LAYOUT status prgstat KBD keyseq

  if {$prgstat(running)} {
    prgm_interrupt
    return
  }

  if {[lindex [.gui gettags pressed] 0] eq ""} {
    .gui addtag pressed withtag $btn
    .gui itemconfigure $btn\_h -outline $LAYOUT(button_bg)
    .gui move $btn 0 -1
    set KBD(state) 0
    update idletasks

# This is where USER mode is handled
    if {$status(user) && [regexp {^(42_)*1[1-5]$} $code]} {
      if {[regexp {^42_} $code] || $status(f)} {
        regsub {^42_} $code {} code
        if {$keyseq eq "42"} {
          set keyseq ""
          set_status fg_off
        }
      } elseif {$keyseq eq ""} {
        set code 32_$code
      } else {
        set code 42_$code
      }
    } elseif {$status(user) && $status(f) && [regexp {^43_1[1-5]$} $code]} {
        regsub {^43_} $code {} code
        set keyseq ""
        set_status fg_off
    }

    dispatch_key $code
  }

}

# ------------------------------------------------------------------------------
proc key_release { btn }  {

  global KBD

  after 30
  set pbtn [lindex [.gui gettags pressed] 0]
  .gui dtag $pbtn pressed
  .gui itemconfigure $pbtn\_h -outline [.gui itemcget $pbtn\_h -fill]
  .gui move $pbtn 0 1
  update
  set KBD(state) 1

  if {[seq_pending] ne ""} {
    dispatch_key [seq_pending]
  }

}

# ------------------------------------------------------------------------------
proc kp_key_press { state btn kcode } {

# Dispatch key-pad key as digit key if NumLock is on.
  if {[expr $state & 16] == 16} {
    key_press btn_$btn $kcode
  }

}

# ------------------------------------------------------------------------------
proc kp_key_release { state btn } {

# Dispatch key-pad key as digit key if NumLock is on.
  if {[expr $state & 16] == 16} {
    key_release btn_$btn
  }

}

# ------------------------------------------------------------------------------
proc hover_enter_f { btn } {

  global LAYOUT HP15 status

  if {$HP15(secondaryclick) && $HP15(secondaryhilight) && $status(g) == 0} {
    .gui itemconfigure $btn\_fbg -outline $LAYOUT(fbutton_bg) \
      -fill $LAYOUT(fbutton_bg)
    .gui itemconfigure $btn\_ftxt -fill black
  }

}

# ------------------------------------------------------------------------------
proc hover_leave_f { btn } {

  global LAYOUT

  .gui itemconfigure $btn\_fbg -outline $LAYOUT(keypad_bg) -fill $LAYOUT(keypad_bg)
  .gui itemconfigure $btn\_ftxt -fill $LAYOUT(fbutton_bg)

}

# ------------------------------------------------------------------------------
proc hover_enter_g { btn } {

  global LAYOUT HP15 status

  if {$HP15(secondaryclick) && $HP15(secondaryhilight) && $status(f) == 0} {
    .gui itemconfigure $btn\_gbg -outline $LAYOUT(gbutton_bg) \
      -fill $LAYOUT(gbutton_bg)
    .gui itemconfigure $btn\_gtxt -fill black
  }

}

# ------------------------------------------------------------------------------
proc hover_leave_g { btn } {

  global LAYOUT

  .gui itemconfigure $btn\_gbg -outline $LAYOUT(button_bg_l) \
    -fill $LAYOUT(button_bg_l)
  .gui itemconfigure $btn\_gtxt -fill $LAYOUT(gbutton_bg)

}

# ------------------------------------------------------------------------------
proc roundRect { w x0 y0 x3 y3 radius args } {

  set r [winfo pixels $w $radius]
  set d [expr 2*$r]
  set maxr 0.75

  if { $d > $maxr * ($x3-$x0) } {
    set d [expr $maxr * ($x3-$x0)]
  }
  if { $d > $maxr * ($y3-$y0) } {
    set d [expr $maxr * ($y3-$y0)]
  }

  set x1 [expr $x0 + $d]
  set x2 [expr $x3 - $d]
  set y1 [expr $y0 + $d]
  set y2 [expr $y3 - $d]

  set cmd [list $w create polygon]
  lappend cmd $x0 $y0 $x1 $y0 $x2 $y0 $x3 $y0 $x3 $y1 $x3 $y2 $x3 $y3 $x2 $y3 \
    $x1 $y3 $x0 $y3 $x0 $y2 $x0 $y1 -smooth 1

  return [eval $cmd $args]

}

# ------------------------------------------------------------------------------
proc hp_key { x y wid hei kk } {

  global LAYOUT HP15

  lassign $kk k0 k1 rows kcode utext mtext ltext fbnd bnd gbnd

  set fghei [winfo pixels . [font actual $LAYOUT(FnFGBtn) -size]p]
  set bheight [expr round($hei * 0.596)]
  set gypos [expr $y+($hei * 0.81)]
  if {$rows == 2} {
    set bheight [expr round($hei * 0.8653)]
    set gypos [expr $y+($hei * 0.9327)]
  }
  set rd [expr int([winfo pixels . [font actual $LAYOUT(FnButton) -size]p]*0.24)]
  set btn btn_$k0$k1

  roundRect .gui [expr $x-3] [expr $y-4] [expr $x+$wid+2] [expr $y+$hei+2] $rd \
    -outline black -fill black -tags $btn\_outer

# upper (gold) function
  .gui create text [expr $x+$wid/2] [expr $y-4] \
    -text $utext -anchor s -font $LAYOUT(FnFGBtn) -fill $LAYOUT(fbutton_bg) \
    -tags [list $btn\_f $btn\_ftxt]
  if {$utext ne "" && $HP15(secondaryclick)} {
    .gui create rectangle $x [expr $y-6-$fghei] [expr $x+$wid] [expr $y-5] \
      -outline $LAYOUT(keypad_bg) -fill $LAYOUT(keypad_bg) \
      -tags [list $btn\_f $btn\_fbg]
    .gui raise $btn\_ftxt $btn\_fbg
    .gui bind $btn\_f "<ButtonPress-1>" "key_press $btn 42_$kcode"
    .gui bind $btn\_f "<ButtonRelease-1>" "key_release $btn"
  }
  foreach kk $fbnd {
    bind . <KeyPress-$kk> "key_press $btn 42_$kcode"
    bind . <KeyRelease-$kk> "key_release $btn"
  }
  .gui bind $btn\_f <Enter> "hover_enter_f $btn"
  .gui bind $btn\_f <Leave> "hover_leave_f $btn"

# basic function
  roundRect .gui [expr $x-1] [expr $y-1] [expr $x+$wid] [expr $y+$hei] $rd \
    -outline grey50 -fill grey50 -tags $btn\_h
  roundRect .gui $x $y [expr $x+$wid] [expr $y+$bheight+3] $rd \
    -outline $LAYOUT(button_bg) -fill $LAYOUT(button_bg) \
    -tags [list $btn $btn\_b $btn\_bg]
  roundRect .gui $x [expr $y+$bheight] [expr $x+$wid] [expr $y+$hei] $rd \
    -outline $LAYOUT(button_bg_l) -fill $LAYOUT(button_bg_l) \
    -tags [list $btn $btn\_g $btn\_gbg]
  if {$ltext eq ""} {
    .gui itemconfigure $btn\_gbg -outline $LAYOUT(button_bg) \
      -fill $LAYOUT(button_bg) -tags [list $btn $btn\_b $btn\_bg]
  }
  .gui create text [expr $x+$wid/2] $y \
    -text $mtext -font $LAYOUT(FnButton) -fill white -anchor n \
    -tags [list $btn $btn\_b $btn\_t]
  .gui create line $x [expr $y+$bheight] \
    [expr $x+$wid] [expr $y+$bheight] -width 2 -fill $LAYOUT(button_sep) \
    -tags [list $btn $btn\_b $btn\_ed]

  .gui bind $btn\_b <ButtonPress-1> "key_press $btn $kcode"
  .gui bind $btn\_b <ButtonRelease-1> "key_release $btn"
  foreach kk $bnd {
    bind . <KeyPress-$kk> "key_press $btn $kcode"
    bind . <KeyRelease-$kk> "key_release $btn"
  }

# lower (blue) function
  if {$ltext ne ""} {
    .gui create text [expr $x+$wid/2] $gypos \
      -text $ltext -anchor c -font $LAYOUT(FnFGBtn) -fill $LAYOUT(gbutton_bg) \
      -tags [list $btn $btn\_g $btn\_gtxt]
    if {$HP15(secondaryclick)} {
      .gui bind $btn\_g "<ButtonPress-1>" "key_press $btn 43_$kcode"
      .gui bind $btn\_g "<ButtonRelease-1>" "key_release $btn"
    } else {
      .gui bind $btn\_g "<ButtonPress-1>" "key_press $btn $kcode"
      .gui bind $btn\_g "<ButtonRelease-1>" "key_release $btn"
    }
  }
  foreach kk $gbnd {
    bind . <KeyPress-$kk> "key_press $btn 43_$kcode"
    bind . <KeyRelease-$kk> "key_release $btn"
  }
  .gui bind $btn\_g <Enter> "hover_enter_g $btn"
  .gui bind $btn\_g <Leave> "hover_leave_g $btn"

}

# ------------------------------------------------------------------------------
proc toggle_binary { n1 {n2 ""} } {

  upvar $n1 v1

  if {$n2 eq "" } {
    set $v1 [expr !$v1]
  } else {
    set v1($n2) [expr !$v1($n2)]
  }

}

# ------------------------------------------------------------------------------
proc gui_setpos { wp } {

  if {$wp ne ""} {
    catch {
      update
      regexp {\+(-?\d+)\+(-?\d+)} $wp all xp yp
      if {$xp >= [winfo vrootx .] && $xp+[winfo reqwidth .] <= [winfo vrootwidth .] &&
          $yp >= [winfo vrooty .] && $yp+[winfo reqheight .] <= [winfo vrootheight .]} {
        wm geom . $wp
      }
    }
  }

}

# ------------------------------------------------------------------------------
proc gui_top { {toggle ""} } {

  global HP15

  if {$toggle eq "TOGGLE"} {set ::HP15(wm_top) [expr !$::HP15(wm_top)]}

  wm attributes . -topmost $HP15(wm_top)

}

# ------------------------------------------------------------------------------
proc gui_raise {} {

  foreach cc [winfo children .] {
    if {[winfo toplevel $cc] == $cc && ![catch {$cc cget -menu}]} {
      catch {raise $cc}
    }
  }
  raise .

}

# ------------------------------------------------------------------------------
proc gui_draw {} {

  global APPDATA LAYOUT HP15_KEYS HP15

  if {[winfo exists .gui]} {destroy .gui}

  fontset_apply $HP15(fsid)

# Button and keypad size and position
  set bhei [expr [font metrics $LAYOUT(FnButton) -linespace] + \
    [font metrics $LAYOUT(FnFGBtn) -linespace]]
  set bwid [expr int(ceil($bhei/0.85))]
  set hspace [expr round($bwid * 1.5)]
  set vspace [expr round($bwid * 1.667)]

  set bdoffs [expr round($bwid * 0.1)]
  set bdwid [expr round($bwid * 0.095)]
  set xkpoffs [expr round($bwid * 0.6)]
  set ykpoffs [expr round($bwid * 0.61)]
  set kpwid [expr 2*$xkpoffs + 9*$hspace + $bwid]
  set kphei [expr 2*$ykpoffs + 3*$vspace + $bhei + 5]

  set digiheit [expr [winfo pixels . [font actual $LAYOUT(FnDisplay) -size]p]]

# Display area size
  set dsparea 0.42
  set dsphei [expr $kphei*0.24]
  set dspy0 [expr $dsphei*0.44]
  if {[tk windowingsystem] eq "aqua"} {
    set digiheit [expr $dsphei*0.57]
  } else {
    set digiheit [expr $dsphei*0.51]
  }

  set sephei 5
  canvas .gui -width $kpwid -height [expr $kphei*(1.0+$dsparea)+$sephei] \
    -bg $LAYOUT(keypad_bg) -highlightthickness 0
  grid .gui -row 0 -column 1

# Display area
  if {[info exists APPDATA(beveltop)] && [info exists APPDATA(dispframe)]} {
    .gui create image 0 0 -image $APPDATA(beveltop) -anchor nw -tags dsparea
    .gui create image 0 [font actual $LAYOUT(FnButton) -size] \
      -image $APPDATA(dispframe) -anchor nw -tags dsparea
  } else {
    .gui create rectangle 0 0 $kpwid [expr $kphei*$dsparea] \
      -fill $LAYOUT(display_outer_frame) -width 0 -tags dsparea
    .gui create rectangle 0 0 $kpwid 12 -fill $LAYOUT(display_top_frame) \
     -width 0 -tags dsparea
  }

  roundRect .gui [expr $xkpoffs+$hspace] $dspy0 \
    [expr $xkpoffs+6*$hspace+$bwid*1.18] [expr $dspy0+$dsphei] 5 \
    -outline #9C9E9E -fill #9C9E9E
  roundRect .gui [expr $xkpoffs+$hspace+2] [expr $dspy0+1] \
    [expr $xkpoffs+6*$hspace+$bwid*1.18] [expr $dspy0+$dsphei] 5 \
    -outline #F5F8F8 -fill #F5F8F8 -tag dspsize
  roundRect .gui [expr $xkpoffs+$hspace+2] [expr $dspy0+1] \
    [expr $xkpoffs+6*$hspace+$bwid*1.18-2] [expr $dspy0+$dsphei-1] 5 \
    -outline $LAYOUT(display_inner_frame) -fill $LAYOUT(display_inner_frame)

  roundRect .gui [expr $xkpoffs+$hspace+$bwid/3+1] [expr $dspy0+3] \
     [expr $xkpoffs+6*$hspace+$bwid*0.8] [expr $dspy0+$dsphei-4] 5 \
     -outline #EFF4F3 -fill $LAYOUT(display)
  roundRect .gui [expr $xkpoffs+$hspace+$bwid/3] [expr $dspy0+2] \
    [expr $xkpoffs+6*$hspace+$bwid*0.8-1] [expr $dspy0+$dsphei-5] 5 \
    -outline #69695A -fill $LAYOUT(display)
   roundRect .gui [expr $xkpoffs+$hspace+$bwid/3+1] [expr $dspy0+3] \
     [expr $xkpoffs+6*$hspace+$bwid*0.8-1] [expr $dspy0+$dsphei-5] 5 \
     -outline $LAYOUT(display) -fill $LAYOUT(display) -tags dspbg

# Calculate positions for X register display
  set xpos1 [lindex [.gui bbox dspbg] 0]
  set xpos2 [lindex [.gui bbox dspbg] 2]

  set dwid [expr ($xpos2 - $xpos1)/11.0]
  set xpos [expr $xpos1 - $dwid*0.25 ]

  if {$HP15(usetkpath)} {
    set sfac [expr [font actual $LAYOUT(FnDisplay) -size]/744.0]
    ::tkp::canvas .gui.c -width [expr 5*$hspace+$bwid*0.3] -height $digiheit \
      -bg $LAYOUT(display) -highlightthickness 0

    ::hplcd::Draw .gui.c d0
    .gui.c itemconfigure d0 -matrix [list {1 0} {0 1} [list 0 2]]
    .gui.c addtag digit withtag d0
    .gui.c scale d0 0 0 $sfac $sfac
    set xp [expr $dwid*0.7]
    for {set ii 1} {$ii < 11} {incr ii} {
      ::hplcd::Draw .gui.c d$ii
      .gui.c scale d$ii 0 0 $sfac $sfac
      .gui.c itemconfigure d$ii -matrix [list {1 0} {0 1} [list $xp 2]]
      .gui.c addtag digit withtag d$ii
      set xp [expr $xp+$dwid]
    }
  } else {
    canvas .gui.c -width [expr 5*$hspace+$bwid*0.3] -height $digiheit \
      -bg $LAYOUT(display) -highlightthickness 0

    set xp [expr $dwid*0.66]
    .gui.c create text $xp 0 -anchor ne -tags d0
    for {set ii 1} {$ii < 11} {incr ii} {
      .gui.c create text $xp 0 -anchor nw -tags d$ii
      .gui.c create text [expr $xp+($dwid*0.68)] 0 -anchor nw -tags p$ii
      set xp [expr $xp+$dwid]
    }
    .gui.c itemconfigure all -font $LAYOUT(FnDisplay)
    .gui.c addtag digit all
    .gui.c addtag On all
  }
  set ypos [expr $dsphei*1.11]
  .gui create window [expr $xkpoffs+$hspace+$bwid/3+2] $ypos \
    -window .gui.c -anchor sw -tags guiwin

# Calculate positions for status display
  set x0 [expr $xkpoffs+$hspace+$bwid/3+2+$dwid*0.7]
  foreach {tname xpos} {seqindicator -0.25 user 1.45 f 2.2 g 2.9 begin 4.53 \
    rad 6.3 dmy 7.4 complex 8.2 prgm 9.8} {
    .gui create text [expr $x0+$dwid*$xpos] $ypos \
      -font $LAYOUT(FnStatus) -anchor ne -tags [list s$tname dspbg]
  }

# Draw logo

  set glyphhp {
    M 265 3 L 3 735 L 111 735 L 249 356 L 331 356 L 193 735 L 301 735 L 429 382
    Q 443 344 424 316 Q 406 289 365 289 L 274 289 L 378 3 Q 378 3 265 3 M 387 1021
    L 490 735 L 634 735 Q 652 735 670.0 723.0 Q 688 711 695 692 L 808 382 Q 822 343
    803.0 316.0 Q 784 289 743 289 L 544 289 L 377 748 L 277 1021 L 387 1021
    M 710 356 L 596 668 L 515 668 L 628 356 L 710 356
  }

  set glyph15C {
    M 462 3 L 462 749 L 259 749 L 259 199 L 150 313 L 137 313 L 3 183 L 182 3
    L 462 3 M 1456 3 L 1456 152 L 755 152 L 755 278 Q 788 266 826 256 Q 849 251
    868 248 Q 881 247 882 246 L 887 246 Q 892 246 900 245 L 1110 245 L 1166 246
    L 1222 248 Q 1237 248 1250.5 249.5 Q 1264 251 1278 253 Q 1398 265 1438.0 319.0
    Q 1478 373 1478 480 Q 1478 615 1422 678 Q 1390 711 1340.0 729.0 Q 1290 747
    1207 749 L 784 749 Q 717 749 673.0 730.0 Q 629 711 603 680 Q 550 617 542 515
    L 755 515 Q 759 558 791 582 Q 811 589 823.5 591.0 Q 836 593 855 593 L 870 593
    L 885 594 L 869 594 L 988 596 L 1092 595 Q 1164 595 1201.0 579.5 Q 1238 564
    1238 495 Q 1238 438 1211 417 Q 1197 406 1174.0 400.0 Q 1151 394 1118 394
    L 1096 392 L 1073 392 L 1028 391 L 856 391 L 822 394 Q 805 395 790 400 Q 775 404
    766.0 413.0 Q 757 422 755 439 L 543 439 L 544 3 L 1456 3 M 2502 463 Q 2501 627
    2454 693 Q 2424 718 2365.5 731.0 Q 2307 744 2236 749 L 1922 749 Q 1853 746
    1790.0 737.5 Q 1727 729 1675.0 713.0 Q 1623 697 1593 648 Q 1564 568 1563 507
    L 1558 426 L 1558 326 L 1563 245 Q 1565 185 1603 107 Q 1629 62 1684 35 Q 1744
    8 1833 9 Q 1870 6 1892.0 4.5 Q 1914 3 1942 3 L 2105 3 L 2175 4 Q 2189 4 2207.5 5.0
    Q 2226 6 2248 8 L 2272 8 Q 2277 8 2318 13 Q 2437 25 2470 96 Q 2485 135 2493.5 177.5
    Q 2502 220 2502 269 L 2272 269 Q 2266 216 2237 200 Q 2221 191 2202.5 186.5
    Q 2184 182 2160 182 Q 2149 182 2143 181 L 2042 181 L 1953 182 Q 1835 182
    1815.5 227.5 Q 1796 273 1796 375 Q 1796 487 1818 526 Q 1832 545 1867.5 556.5
    Q 1903 568 1973 568 L 2034 570 L 2081 570 Q 2087 569 2090 569 L 2143 569
    Q 2202 569 2237.0 553.0 Q 2272 537 2272 463 L 2502 463
  }

  set lx [expr $xkpoffs + 9*$hspace - 2]
  set ly [expr $dspy0 + 2]
  set lsize [expr int($bwid*1.25)]
  set lwid [expr int($lsize*0.85)]
  set lhei1 [expr int($lsize*0.52)]
  set lhei2 [expr int($lsize*0.30)]
  set lpad [expr int(($lsize-$lwid)/2.0)]
  set logox [expr $lpad+0.5*$lwid]

  if {$HP15(usetkpath)} {
    ::tkp::canvas .gui.logo -width $lsize -height $lsize \
      -bg #F2F3F2 -highlightthickness 0
  } else {
    canvas .gui.logo -width $lsize -height $lsize -bg #F2F3F2 \
      -highlightthickness 0
  }

  roundRect .gui.logo 0 0 $lsize $lsize 3 \
    -fill $LAYOUT(keypad_bg)
  roundRect .gui.logo 1 1 [expr $lsize-2] [expr $lsize-2] 3 \
    -outline black -fill $LAYOUT(keypad_bg)
  roundRect .gui.logo $lpad $lpad [expr $lsize-$lpad] [expr $lpad+$lhei1] 3 \
    -fill $LAYOUT(display_inner_frame)
  set osiz [expr $lhei1/2]
  .gui.logo create oval \
    [expr $logox-$osiz] [expr $lpad+0.5*$lhei1-$osiz-1] \
    [expr $logox+$osiz] [expr $lpad+0.5*$lhei1+$osiz-1] \
    -fill $LAYOUT(keypad_bg) -outline $LAYOUT(keypad_bg)
  roundRect .gui.logo $lpad [expr $lhei1+2.0*$lpad-1.0] \
    [expr $lsize-$lpad] [expr $lsize-$lpad] 3 \
    -fill $LAYOUT(display_inner_frame)

  if {$HP15(usetkpath)} {
    .gui.logo create path $glyphhp -stroke "" -tags glyphhp \
      -fill $LAYOUT(display_inner_frame)
    .gui.logo itemconfigure glyphhp -matrix [list {1 0} {0 1} \
      [list [expr $logox-0.75*$osiz] [expr $lpad-0.5]]]
    set sfac [expr $lwid/1675.0]
    .gui.logo scale glyphhp 0 0 $sfac $sfac

    .gui.logo create path $glyph15C -stroke "" -tags glyph15c \
      -fill $LAYOUT(keypad_bg)
    .gui.logo itemconfigure glyph15c -matrix [list {1 0} {0 1} \
      [list [expr $lpad+2.0] [expr $lhei1+2.0*$lpad]]]
    set sfac [expr $lwid/2900.0]
    .gui.logo scale glyph15c 0 0 $sfac $sfac

  } else {
    .gui.logo create text [expr $logox+1] [expr $lpad+$lhei1] -anchor s \
      -text $APPDATA(hp) -font $LAYOUT(FnLogo1) -fill $LAYOUT(display_inner_frame) \
      -justify center
    .gui.logo create text $logox [expr $lsize-$lpad+1] -anchor s \
      -text $APPDATA(15C) -font $LAYOUT(FnLogo2) -fill $LAYOUT(keypad_bg)
  }
  .gui create window $lx $ly -window .gui.logo -anchor nw -tags guiwin

# Separator
  frame .gui.sep -background $LAYOUT(keypad_bg) -height $sephei\p -relief raised \
    -borderwidth 2
  .gui create rectangle 0 [expr $kphei*$dsparea] $kpwid [expr $kphei*$dsparea+40] \
    -fill $LAYOUT(keypad_bg)
  .gui create window -2 [expr $kphei*$dsparea] -window .gui.sep -anchor w \
    -height $sephei\p -width [expr $kpwid+2] -tag [list seperator guiwin]

# Keyboard
  set kpy0 [expr $kphei*$dsparea+6]
  .gui create rectangle 0 $kpy0 $kpwid [expr $kphei+$kpy0] \
    -fill $LAYOUT(keypad_bg) -width 0

  foreach kk $HP15_KEYS {
    set ix [expr [lindex $kk 1]-1]
    set iy [expr [lindex $kk 0]-1]
    if {[lindex $kk 2] == 2} {
      set bh [expr $bhei+$vspace]
    } else {
      set bh $bhei
    }
    hp_key [expr $hspace*$ix+$xkpoffs] [expr $kpy0+$vspace*$iy+$ykpoffs] $bwid $bh $kk
  }

# Fine tuning fonts and layout
  set psiz [expr int([font actual $LAYOUT(FnFGBtn) -size]*1.4)]
  .gui itemconfigure btn_26_gtxt -font "{[font actual $LAYOUT(FnButton) -family]} $psiz"
  .gui move btn_26_gtxt 0 -1
  .gui itemconfigure btn_49_t -font "{[font actual $LAYOUT(FnFGBtn) -family]} \
    [expr int([font actual $LAYOUT(FnButton) -size]*0.9)] \
    [font actual $LAYOUT(FnButton) -weight]"
  .gui itemconfigure btn_210_ftxt -anchor s \
    -font "{[font actual $LAYOUT(FnFGBtn) -family]} \
    [expr int([font actual $LAYOUT(FnFGBtn) -size]*0.85)]"

# Adjust font size for divide, times and plus button
   set fn "{[font actual $LAYOUT(FnButton) -family]} \
      [expr int([font actual $LAYOUT(FnButton) -size]*1.35)] bold"
   set md [expr -int([font actual $LAYOUT(FnButton) -size]*1.35/4)]
   foreach rr {110 210 310 410} {
    .gui itemconfigure btn_$rr\_t -font $fn
    .gui move btn_$rr\_t 0 $md
   }

# WA-Win: Backward arrow \u2B05 appears boxed under windows, replace it
  if {[tk windowingsystem] eq "win32"} {
    if {$::tcl_platform(osVersion) < 6.1 || $HP15(extendedchars) == 0} {
      .gui itemconfigure btn_35_t -text "\u2190" -font $fn
    } else {
      .gui itemconfigure btn_35_t -text "\u2B09" -font $fn
      .gui itemconfigure btn_35_t -text "\u2B05" -font $fn
    }
  }

  .gui itemconfigure btn_42_bg -outline $LAYOUT(fbutton_bg) \
    -fill $LAYOUT(fbutton_bg)
  .gui itemconfigure btn_42_h -outline #FFEC9F -fill #FFEC9F
  .gui delete btn_42_ed
  .gui itemconfigure btn_42_t -fill black

  .gui itemconfigure btn_43_bg -outline $LAYOUT(gbutton_bg) \
    -fill $LAYOUT(gbutton_bg)
  .gui itemconfigure btn_43_h -outline #B6FFFF -fill #B6FFFF
  .gui delete btn_43_ed
  .gui itemconfigure btn_43_t -fill black

  .gui delete btn_41_ed
  .gui move btn_41_t 0 [expr $bhei/4]

# Background for Integral
  if {$HP15(secondaryclick)} {
    set int_coords [.gui coords btn_210_fbg]
    lset int_coords 1 [expr [lindex [.gui bbox btn_210_ftxt] 1]]
    .gui coords btn_210_fbg $int_coords
  }

# ENTER key label
  .gui delete btn_36_t
  set e_x \
    [expr ([lindex [.gui bbox btn_36_b] 0]+[lindex [.gui bbox btn_36_b] 2])/2.0]
  set e_y [lindex [.gui bbox btn_36_b] 1]
  set e_dy [expr ([lindex [.gui bbox btn_36_ed] 1] - $e_y)/5.9]
  for {set ii 0} {$ii < 5} {incr ii} {
    .gui create text $e_x [expr $e_y + ($ii+0.4)*$e_dy] \
       -text [string index "ENTER" $ii] -font $LAYOUT(FnButton) -anchor n \
       -fill $LAYOUT(keypad_frame) -tags [list btn_36 btn_36_b btn_36_t]
  }

# "CLEAR" bar
  set fnsize [font actual $LAYOUT(FnClear) -size]
  set x1 [lindex [.gui bbox btn_32_outer] 0]
  set x2 [lindex [.gui bbox btn_35_outer] 2]
  set cx [expr [lindex [.gui bbox btn_32_outer] 0] + ($x2-$x1)/2]
  set dy2 [expr $fnsize/2.0]
  set y1 [expr [lindex [.gui bbox btn_33_ftxt] 1] - $dy2]
  set y2 [expr [lindex [.gui bbox btn_33_ftxt] 1] + 2]
  .gui create line $x1 $y2 $x1 $y1 $x2 $y1 $x2 $y2 \
    -width 0 -fill $LAYOUT(fbutton_bg) -tags clear_mark
  .gui create text $cx $y1 -text " CLEAR " -font $LAYOUT(FnClear) \
    -fill $LAYOUT(fbutton_bg) -anchor center -tags clear_t
  .gui create rectangle [lindex [.gui bbox clear_t] 0] [expr $y1+$dy2] \
    [lindex [.gui bbox clear_t] 2] [expr $y1-$dy2] \
    -fill $LAYOUT(keypad_bg) -width 0 -tags clear_box
  .gui raise clear_t

  set fx1 $bdoffs
  set fx2 [expr $kpwid - $bdoffs]
  set fy2 [expr [lindex [.gui bbox btn_41] 3] + $ykpoffs - $bdoffs - \
    [font actual $LAYOUT(FnBrand) -size]]
  set fx3 [lindex [.gui bbox btn_41_outer] 0]
  set fy3 [expr $fy2 + [font actual $LAYOUT(FnBrand) -size]/2]

# Keypad frame
  set fy1 $bdoffs
  .gui create rectangle $fx1 $kpy0 $fx2 [expr $kpy0 + $bdwid] \
    -fill $LAYOUT(keypad_frame) -width 0 -tag kpframe
  .gui create rectangle $fx1 $kpy0 [expr $fx1 + $bdwid] $fy3 \
    -fill $LAYOUT(keypad_frame) -width 0 -tag kpframe
  .gui create rectangle [expr $fx2 - $bdwid] $kpy0 $fx2 $fy3 \
    -fill $LAYOUT(keypad_frame) -width 0 -tag kpframe

  roundRect .gui $fx1 $fy2 $fx2 [expr $fy2+[font actual $LAYOUT(FnBrand) -size]] \
    3 -fill $LAYOUT(keypad_frame) -width 0 -tag kpframe

  set fx4 [lindex [.gui bbox btn_45_h] 2]
  set dx [expr ($fx4-$fx3)/([string length $APPDATA(brand)]+0.5)]
  for {set ii 0} {$ii < [string length $APPDATA(brand)]} {incr ii} {
    .gui create text [expr $fx3+$ii*$dx+$dx/2.0] $fy3 \
       -text [string index $APPDATA(brand) $ii] -font $LAYOUT(FnBrand) \
       -fill $LAYOUT(keypad_frame) -anchor w -tags brand_t
  }
  .gui create rectangle $fx3 $fy2 $fx4 \
    [expr $fy2+[font actual $LAYOUT(FnBrand) -size]] -fill $LAYOUT(keypad_bg) \
    -width 0
  .gui raise brand_t

# Additional keyboard and mouse bindings not done in procedure 'hp_key'.

  .gui bind btn_42_b <ButtonPress-1> "key_f 0"
  .gui bind btn_42_b <ButtonRelease-1> "key_f 1"
  bind . <KeyPress-f> "key_f 0"
  bind . <KeyRelease-f> "key_f 1"

  .gui bind btn_43_b <ButtonPress-1> "key_g 0"
  .gui bind btn_43_b <ButtonRelease-1> "key_g 1"
  bind . <KeyPress-g> "key_g 0"
  bind . <KeyRelease-g> "key_g 1"

  bind . <KeyPress-Right> "key_press btn_21 21"
  bind . <KeyRelease-Right> "key_release btn_21"

  bind . <KeyPress-Left> "key_press btn_21 43_21"
  bind . <KeyRelease-Left> "key_release btn_21"

  bind . <KeyPress-space> "key_press btn_35 42_35"
  bind . <KeyRelease-space> "key_release btn_35"

  bind . <KeyPress-i> "key_press btn_24 42_24"
  bind . <KeyRelease-i> "key_release btn_24"

# Secondary function bindings can be disabled
  if {$HP15(secondaryclick)} {
    .gui bind btn_21_g <ButtonPress-1> "key_press btn_21 43_21"
    .gui bind btn_21_g <ButtonRelease-1> "key_release btn_21"

    .gui bind btn_24_f <ButtonPress-1> "key_press btn_24 42_24"
    .gui bind btn_24_f <ButtonRelease-1> "key_release btn_24"

    .gui bind btn_35_f <ButtonPress-1> "key_press btn_35 42_35"
    .gui bind btn_35_f <ButtonRelease-1> "key_release btn_35"

    .gui bind btn_45_g <ButtonPress-1> "key_press btn_45 43_45"
    .gui bind btn_45_g <ButtonRelease-1> "key_release btn_45"
  } else {
# Key 21 is the only key that has "hold" behaviour without modifier
     .gui bind btn_21_g <ButtonPress-1> "key_press btn_21 21"
     .gui bind btn_21_g <ButtonRelease-1> "key_release btn_21"
  }

# We must handle NumLock state on our own under UNIX; but not on macOS
  if {$::tcl_platform(platform) eq "unix" && $::tcl_platform(os) ne "Darwin"} {
    foreach {kpk btn kcode} {Home 17 7 Up 18 8 Prior 19 9 Left 27 4 Begin 28 5 \
      Right 29 6 End 37 1 Down 38 2 Next 39 3 Insert 47 0} {
      bind . <KeyPress-KP_$kpk> "kp_key_press %s $btn $kcode"
      bind . <KeyRelease-KP_$kpk> "kp_key_release %s $btn"
    }
    bind . <KeyPress-KP_Delete> "kp_key_press %s 48 48"
    bind . <KeyRelease-KP_Delete> "kp_key_release %s 48"
  }

# Alt/Option modifier bindings
  foreach {lbl kk} {a 11 b 12 c 13 d 14 e 15} {
    bind . <$APPDATA(option)-KeyPress-$lbl> "key_press btn_$kk 42_$kk"
    bind . <$APPDATA(option)-KeyRelease-$lbl> "key_release btn_$kk"
  }
  foreach altkey { {x 11 43_11} {n 12 43_12} {g 13 43_13} {slash 15 15} \
    {plus 16 16} {minus 16 16} {h 22 43_22} {less 27 42_4} {greater 27 42_4} } {
    lassign $altkey key btn code
    bind . <$APPDATA(option)-KeyPress-$key> "key_press btn_$btn $code"
    bind . <$APPDATA(option)-KeyRelease-$key> "key_release btn_$btn"
  }

# Pop-up menu bindings
  .gui bind btn_41 <<B3>> "show_on_options MOUSE"
  .gui bind dsparea <<B3>> "show_on_options MOUSE"
  .gui.logo bind all <<B3>> "show_on_options MOUSE"
  bind . <$APPDATA(option)-o> "show_on_options kbd"
  bind . <F10> "show_on_options kbd"

  .gui bind btn_44 <<B3>> "show_storage 44 MOUSE"
  bind . <$APPDATA(option)-m> "show_storage 44 kbd"
  .gui bind btn_45 <<B3>> "show_storage 45 MOUSE"
  bind . <$APPDATA(option)-r> "show_storage 45 kbd"
  .gui bind btn_29_g <<B3>> "show_flags MOUSE"
  bind . <$APPDATA(option)-f> "show_flags kbd"
  .gui bind btn_310_g <<B3>> "show_test_options MOUSE"
  bind . <$APPDATA(option)-t> "show_test_options kbd"

  .gui bind btn_22 <<B3>> "func_gto_chs MOUSE"
  .gui bind btn_32 <<B3>> "show_labels MOUSE"
  bind . <$APPDATA(option)-F3> "show_labels kbd"

  .gui bind dspbg <<B3>> "show_content MOUSE"
  bind .gui.c <<B3>> "show_content MOUSE"
  bind . <$APPDATA(option)-s> "show_content kbd"

  for {set kk 1} {$kk < 6} {incr kk} {
    .gui bind btn_1$kk\_f <<B3>> "show_matrix M$kk MOUSE btn_1$kk\_f"
  }

  bind . <$APPDATA(option)-z> "show_matrix_funcs kbd"
  .gui bind btn_16_f <<B3>> "show_matrix_funcs MOUSE"

# Miscellaneous HP-15C function bindings
  bind . <Shift-Escape> clearall
  bind . <$APPDATA(option)-period> exchange_seps
  bind . <$APPDATA(option)-comma> exchange_seps

  for {set ii 0} {$ii < 10} {incr ii} {
    bind . <$APPDATA(option)-Key-$ii> "dispatch_key 32_$ii"
  }

# Mac keyboards do not have an Insert key.
  bind . <$APPDATA(option)-KeyPress-Return> "key_press btn_49 49"
  bind . <$APPDATA(option)-KeyRelease-Return> "key_release btn_49"

  bind . <MouseWheel> "disp_scroll %D"

# Additional program bindings
  bind . <F11> {toggle_binary ::HP15 mnemonics}
  bind . <$APPDATA(option)-F11> {toggle_binary ::HP15 prgmcoloured}

  bind . <F12> "::prdoc::Edit"

  bind . <$APPDATA(control)-comma> preferences

# Operating system related bindings
  bind . <F1> {help simulator}
  bind . <$APPDATA(control)-F1> {help prgm}
  bind . <Shift-F1> {help prgm}
  if {[tk windowingsystem] ne "aqua"} {
    bind . <$APPDATA(control)-F2> "mbar_show 1"
  }
  bind . <$APPDATA(control)-q> "exit"
  bind . <$APPDATA(control)-c> "clipboard_set 0"
# Must define upper and lower case combination because OSes handle it differently
  bind . <$APPDATA(control)-Shift-C> "clipboard_set 1"
  bind . <$APPDATA(control)-Shift-c> "clipboard_set 1"
  .gui bind dspbg <Double-1> "clipboard_set 0"
  .gui.c bind all <Double-1> "clipboard_set 0"
  .gui bind digit <Double-1> "clipboard_set 0"
  bind . <$APPDATA(control)-v> "clipboard_get"
  if {[tk windowingsystem] eq "aqua"} {
    bind . <ButtonPress-3> "clipboard_get"
  } else {
    bind . <ButtonPress-2> "clipboard_get"
  }
  bind . <$APPDATA(control)-m> "mem_save"
  bind . <$APPDATA(control)-l> "mem_load"
  bind . <$APPDATA(control)-r> "mem_reset"
  bind . <$APPDATA(control)-o> "prgm_getfile"
  bind . <$APPDATA(control)-s> "prgm_save"
  bind . <$APPDATA(control)-d> "::prdoc::Edit"
  bind . <$APPDATA(control)-e> {prgm_save "[mc app.exthtml]"}
  bind . <$APPDATA(control)-t> {gui_top TOGGLE}

  bind . <$APPDATA(control)-plus> "fontset_cycle +"
  bind . <$APPDATA(control)-KP_Add> "fontset_cycle +"
  bind . <$APPDATA(control)-minus> "fontset_cycle -"
  bind . <$APPDATA(control)-KP_Subtract> "fontset_cycle -"

  if {[tk windowingsystem] ne "aqua"} { ;# Avoid conflict with menu bindings
    bind . <$APPDATA(control)-Up> "DM15_do read"
    bind . <$APPDATA(control)-Down> "DM15_do write"
  }
  bind . <$APPDATA(control)-i> "DM15_sysinfo"

  bind . <FocusIn> "gui_raise"

}

# ------------------------------------------------------------------------------
# Startup procedure

# Clear everything and reload previous session
clearall
mem_load
hist_load

# Draw the GUI and define key bindings
gui_draw

trace add variable ::stack(x) write chk_xreg
trace add variable ::stack(y) write chk_range
trace add variable ::curdisp write disp_update
trace add variable ::storage write chk_range
trace add variable ::FLAG(9) write disp_flash

# Update the display
show_x
set_status NIL

# Check for browser configuration
if {![string length $HP15(browser)]} {
  set HP15(browser) [lindex [browser_lookup] 1]
}

# ------------------------------------------------------------------------------
# Window manager configuration & communication

wm protocol . WM_DELETE_WINDOW {exit}
wm title . " $APPDATA(title)"
wm iconname . $APPDATA(appname)
wm resizable . false false
gui_setpos $HP15(winpos)
gui_top
focus -force .

option add *Dialog.msg.font $LAYOUT(FnMenu) userDefault
option add *tearOff 0

# ------------------------------------------------------------------------------
# And now let the window manager show the interface in all it's beauty...
wm deiconify .
#set curdisp "   XP-15C"
