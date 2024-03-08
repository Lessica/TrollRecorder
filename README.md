# TrollRecorder-CLI

A simple audio recorder for TrollStore.

**Only the core codes and command line interfaces are open-sourced. The app is distributed in its binary format as a Troll Store package.**

![Screenshot](./res/screenshot.png)

## Milestones

- [x] Playing &amp; recording via command-line interface
- [x] Pause &amp; resume via signals (`SIGUSR1` &amp; `SIGUSR2`)
- [x] Phone call recording via command-line interface
- [x] Mix/combine stereo audio from both sides of a phone call
- [x] Observe phone calls and trigger required actions
- [x] Elegant app by [@Lakr233](https://github.com/Lakr233)
- [x] Launch in background via App or “Shortcuts”
- [x] Status indicator and toolbar with a global HUD

## Special Thanks

- Audio Mixer: [CallAssist](https://buy.htv123.com) by [@xybp888](https://github.com/xybp888)
- Audio Tap Bypass: [AudioRecorder XS](https://limneos.net/audiorecorderxs/) by [@limneos](https://twitter.com/limneos)
- [iOS Runtime Headers](https://developer.limneos.net/) by [@limneos](https://twitter.com/limneos)
- [LearnAudioToolBox](https://github.com/liuxinxiaoyue/LearnAudioToolBox) by [@liuxinxiaoyue](https://github.com/liuxinxiaoyue)

## License

TrollRecorder-CLI should be a [Free Software](https://www.gnu.org/philosophy/free-sw.html) licensed under the [GNU General Public License](LICENSE).
