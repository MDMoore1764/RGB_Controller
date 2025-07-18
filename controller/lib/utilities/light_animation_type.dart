enum LightAnimationType {
  Flat('flat'),
  Glow('glow'),
  Pulse('pulse'),
  Strobe('strobe'),
  Fade('fade'),
  Rainbow('rainbow'),
  Cycle('cycle'),
  Breathe('breathe'),
  Wave('wave'),
  Fire('fire'),
  Sparkle('sparkle'),
  Flash('flash'),
  Chase('chase'),
  Twinkle('twinkle'),
  Meteor('meteor'),
  Scanner('scanner'),
  Comet('comet'),
  Wipe('wipe'),
  Larson('larson'),
  Fireworks('fireworks'),
  Confetti('confetti'),
  Ripple('ripple'),
  Noise('noise'),
  ILY('ily');

  final String command;
  const LightAnimationType(this.command);

  String get name => toString().split('.').last;
}
