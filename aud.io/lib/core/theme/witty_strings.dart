class WittyStrings {
  WittyStrings._();

  // ─── Loading screen messages ─────────────────────────────────
  static const List<String> loadingStatuses = [
    "initializing",
    "checking if you're cool enough",
    "loading config (spoiler: it's all lies)",
    "fetching assets you'll never see",
    "installing dependencies that conflict",
    "looking for updates (there are none)",
    "setting up environment (dramatically)",
    "running diagnostics on your patience",
    "connecting to server (it's fine, trust me)",
    "authenticating your soul",
    "compiling resources (praying)",
    "syncing data nobody asked for",
    "optimizing cache (whatever that means)",
    "loading modules from the void",
    "verifying integrity of your attention span",
    "unpacking components dramatically",
    "registering services in the cloud(s)",
    "preparing interface (it still won't look right)",
    "almost ready (lying)",
    "done. you're welcome.",
  ];

  // ─── Player witty remarks ────────────────────────────────────
  static const List<String> nowPlayingJokes = [
    "hurting your ears since 2026",
    "another banger you don't deserve",
    "this track is literally me fr fr",
    "your music taste is… interesting",
    "certified hood classic (probably)",
    "the algorithm™ recommends this",
    "you've heard this 47 times. we know.",
    "this song has more layers than your personality",
    "aud.io approved ✅ (we don't approve anything)",
    "warning: may cause nostalgia",
    "legally distinct from good music",
    "this track was made in a basement",
    "vinyl crackle added for ✨aesthetic✨",
    "loud sounds™",
    "your neighbors hate this one",
    "scientifically proven to be a song",
    "the artist regrets nothing",
    "brought to you by your sleep deprivation",
  ];

  static const List<String> tooltips = [
    "press here. it does something. probably.",
    "this button exists because the designer insisted",
    "disclaimer: may not actually work",
    "i'm as surprised as you are that this works",
    "feature™",
    "please clap",
    "this space intentionally left not blank",
    "guaranteed 60% bug-free",
    "you found the secret! (it's not a secret)",
    "portfolio piece ・ not production ready ・ you're welcome",
    "built with tears and caffeine",
    "made by one person in their pajamas",
    "this app is self-aware. we're all doomed.",
    "breaking the fourth wall since line 1",
    "your mileage may vary (significantly)",
  ];

  static const List<String> emptyLibrary = [
    "wow, so empty. like my social life.",
    "go download some tunes, nerd",
    "nothing here but regret and silence",
    "this library is emptier than a npm install",
    "add some music. or don't. i'm a comment, not a cop.",
    "congratulations, you found nothing",
    "404: Tracks not found",
  ];

  static const List<String> stemSeparation = [
    "separating stems like it's going out of style",
    "isolating vocals and questioning existence",
    "the AI is doing its best (it's not great)",
    "this might take a while. go make tea.",
    "separating: drums from bass, you from your sanity",
    "machine learning: the fancy term for 'guess and check'",
    "your stems, freshly separated and slightly judgmental",
    "processing… please hold… we're also holding",
    "the AI model was trained on 3 songs. this should be fine.",
    "stem separation in progress. science is happening.",
  ];

  static String randomFrom(List<String> list) {
    if (list.isEmpty) return "";
    return list[DateTime.now().millisecondsSinceEpoch % list.length];
  }
}
