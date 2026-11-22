# tornotlukin's OpenTabletDriver plugins

A plugin source for [OpenTabletDriver](https://opentabletdriver.net/)'s Plugin Manager. Add it once and these plugins install, update and uninstall with one click, like the official ones.

| Plugin | What it does | Driver |
|--------|--------------|--------|
| [Buttonalicious](https://github.com/tornotlukin/otd-buttonalicious) | Mouse clicks, double clicks, hold-and-tap and pen-channel taps for pen buttons under the Windows Ink output mode. | 0.6.7 |
| [Penopticon](https://github.com/tornotlukin/otd-penopticon) | Makes the pen act as a plain mouse while chosen apps (e.g. Illustrator, InDesign) have focus; your normal pen setup everywhere else. | 0.6.7 |

## Add this source to OpenTabletDriver

1. Open OpenTabletDriver → **Plugins** → **Open Plugin Manager**.
2. In the Plugin Manager's menu, choose **Use alternate source...**
3. Enter:
   - Owner: `tornotlukin`
   - Name: `otd-plugins`
   - Ref: leave empty
4. Confirm. The list now shows these plugins; select one and click **Install**.

The alternate source replaces the official plugin list while it's active. To browse the official plugins again, reopen the Plugin Manager or use **Refresh**.

Downloads are checked against the SHA256 in each manifest before OpenTabletDriver installs them.

## Manual install

Download the ZIP from the plugin's GitHub Releases page, then in the Plugin Manager choose **Install plugin...** and pick the ZIP.

## Layout

```
Repository/<driver version>/<owner>/<plugin>/<plugin>.json
```

The same manifest format as the official [Plugin-Repository](https://github.com/OpenTabletDriver/Plugin-Repository). OpenTabletDriver reads every `.json` file in this repository as a plugin manifest, so no other JSON files live here.

## Publishing a release (maintainer)

```powershell
pwsh tools/release-plugin.ps1 -PluginRepo ..\otd-penopticon
# tag + push the plugin repo, create the GitHub release, attach the ZIP it printed
pwsh tools/verify-catalog.ps1
# commit + push this repo
```
