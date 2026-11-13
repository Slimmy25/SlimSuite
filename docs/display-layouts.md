# Automatic display layouts

The supplied reference layout uses 1920x1080. Slim Suite measures the current game UI viewport and chooses the closest aspect family: 4:3, 5:4, 16:10, 16:9, 21:9, 32:9 or portrait. It also identifies the nearest of 19 common resolution references from 800x600 through 7680x4320. Intermediate window sizes use their actual measured dimensions rather than snapping the viewport to a preset resolution.

Positions are fractions of the current viewport. Player and target remain at the upper left; the clock and encounters stay at top center; buffs and minimap stay at the upper right. The action bar, XP, tally, level control, build cluster, chat and meter retain the locations in the reference image. Party frames remain below the player; tooltip defaults to the bottom right. Native Default-state elements are left to the game's layout. Enable an element to use its Slim Suite display layout.

Sizes use screen height relative to 1080, multiplied by the user's element scale. Narrow aspect templates reduce density (4:3: 90%, 5:4: 88%, 16:10: 96%, portrait: 70%). A width limit prevents large height scaling from overflowing very narrow windows. Standard and ultrawide templates use 100% density. The native client may express its viewport in UI units; operating-system pixels and the game's UI scaling are not interchangeable.

A half-second layout observer coalesces display changes and defers them during a drag. Only a changed viewport or root scale triggers repositioning. Saved custom locations now include the source viewport bounds, so they adapt proportionally across display changes. Existing saves lacking these bounds capture the current viewport on first use, preserving their initial location and supporting subsequent display changes. Snapped frame-to-frame anchors remain connected. Sizes, orientations, enabled states and per-character layouts are preserved.

The addon adapts to the resolution chosen by the game. It does not add display modes to the engine or change monitor settings.

Validation: mock-client regression scenarios cover aspect selection, proportional anchors, stable repeated scaling, Default-state preservation, edge clamping and repeated resolution return. These checks do not establish actual in-game artwork alignment or visual readability on physical monitors; those require testing in the game.

Extended fuzz seed 19 (800 actions) reproduces an existing local-clock toggle failure in both the untouched 1.22 baseline and this implementation. It is unrelated to display layout changes.
