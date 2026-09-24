cask "ccwidget" do
  version "0.3.5"
  sha256 "9ba6b5302c5bd8d545f6e2d4bc20246a448398a8954419c7559bb6330e9f4b6e"

  url "https://github.com/illvminat/ccwidget/releases/download/v#{version}/CCWidget-#{version}.dmg"
  name "Usage Widget for Claude Code"
  desc "Desktop widget for Claude Code limits, context window and quota estimate"
  homepage "https://github.com/illvminat/ccwidget"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :sonoma

  app "CCWidget.app"

  # Open the app once it is in place, so that a person approves it before the
  # system runs anything out of it. The bundle arrives quarantined, and the
  # first thing macOS executes from a quarantined bundle is judged: opened by a
  # person through the Finder or `open`, a notarized app gets the ordinary
  # "downloaded from the internet — Open?" dialog and is approved from then on;
  # executed first by the widget daemon — which is what happens after an upgrade
  # under a running app, on the next login — the same bundle gets the hard
  # "Apple could not verify" dialog with no Open button, and the widget stays
  # blank until the person finds "Open Anyway" in System Settings. Reproduced
  # on macOS 26.6.2 on 18 August 2026, both ways, in the syspolicyd log.
  #
  # A Ruby flight block rather than postflight_steps: the declarative steps
  # cover file operations only, and the Cask Cookbook keeps the Ruby form for
  # third-party taps. This is a third-party tap; the risk that the form goes
  # away is accepted and this comment is where it is recorded.
  # Quit first, then open. `uninstall quit:` below does the quitting on every
  # upgrade from this cask onwards — but an upgrade is uninstalled by the cask
  # that was installed, not by the one being installed, so the copy running
  # through the first upgrade after this change was never asked to quit, and
  # `open` on a running app only brings its window forward: no evaluation, no
  # approval. Measured on 18 August 2026 with `brew reinstall`. The Apple
  # Event is what `quit:` sends too; a copy that has already quit ignores it.
  postflight do
    system_command "/usr/bin/osascript",
                   args:         ["-e", 'tell application id "dev.illvminat.ccwidget" to quit'],
                   must_succeed: false
    # The upgrade's uninstall step (above) removes the exporter and the
    # statusLine key on its way past. Since 0.3.5 the binary repairs that
    # itself: the flag decides headlessly and exits — it restores setup when
    # the tear-down was an upgrade's, and refuses when a person removed it
    # through the app (the app leaves a marker). Do not ship this line to a
    # cask version older than 0.3.5: earlier binaries do not know the flag
    # and would start the GUI and never exit.
    system_command "#{appdir}/CCWidget.app/Contents/MacOS/CCWidget",
                   args:         ["--reinstall-exporter"],
                   must_succeed: false
    system_command "/usr/bin/open", args: ["-a", "#{appdir}/CCWidget.app"]
  end

  # Deleting the app is not enough. The app writes an exporter into
  # ~/.claude/ccwidget-export.py and points the Claude Code statusLine at it, so
  # removing only the bundle leaves that line running a file that is gone: a
  # broken prompt on every redraw, caused by uninstalling. The uninstaller ships
  # inside the bundle for exactly this, and it puts back whatever status line was
  # there before the widget was installed.
  # `quit:` runs on upgrade and reinstall as well as on uninstall (Cookbook,
  # "uninstall quit"), and it has to: an app left running through an upgrade
  # keeps executing the old bundle, its widget extension included, so the new
  # bundle is first executed by the widget daemon at the next login — the
  # path that ends in the hard dialog described above the postflight.
  uninstall quit:   "dev.illvminat.ccwidget",
            script: {
              executable:   "#{appdir}/CCWidget.app/Contents/Resources/uninstall.sh",
              args:         ["--yes"],
              must_succeed: false,
            }

  # The history the estimate is built from, and the exchange directory the
  # widget extension owns. Left alone by a plain uninstall on purpose: reinstalling
  # keeps the forecast rather than starting it over.
  zap trash: [
    "~/.claude/.ccwidget-export.sha256",
    "~/Library/Containers/dev.illvminat.ccwidget.widget",
  ]

  caveats <<~EOS
    Two things this widget cannot do for you:

      1. Add it to your desktop. Right-click the desktop, Edit Widgets, and find
         "Usage Widget for Claude Code". Do this first — the system creates the
         directory the data goes through, and the app deliberately refuses to
         create it itself.

      2. Configure the status line. Open the app and press "Set up
         automatically". It writes ~/.claude/ccwidget-export.py and points
         statusLine at it, after backing up your settings. If you already have a
         status line, it keeps working: the exporter calls it and prints its
         output.

    It reads the Claude Code status line, which exists only in the terminal
    version. Through the desktop app or the web, the widget stays empty.
  EOS
end
