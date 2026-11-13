import 'package:flutter/material.dart';

import 'paint_kit.dart';
import 'slice_art.dart' show sliceLook;

/// The player's character in each game: its own kit, hair and build of
/// colours, so every game has its own lead and none is a recolour of
/// another. Used by the live scene (camera mirror off) and by the previews.
const melaLook = AvatarLook(
  skin: Color(0xFFB8805C),
  hair: Color(0xFF1E1412),
  top: Color(0xFFE39A1F), // marigold kurta
  bottom: Color(0xFF5B1F2E),
  shoe: Color(0xFFF2E6D0),
  trim: Color(0xFFFF4D6D),
  hairStyle: HairStyle.bun,
);

const patakaLook = AvatarLook(
  skin: Color(0xFFD3A27C),
  hair: Color(0xFF2B1B3A),
  top: Color(0xFF7C5BD6), // stage violet
  bottom: Color(0xFF1F2350),
  shoe: Color(0xFFFFFFFF),
  trim: Color(0xFFFFD23F),
  hairStyle: HairStyle.tied,
  sleeves: false,
);

const duelLook = AvatarLook(
  skin: Color(0xFFA97354),
  hair: Color(0xFF14110F),
  top: Color(0xFF2A3570), // indigo guard's tunic
  bottom: Color(0xFF1A1F3D),
  shoe: Color(0xFF8A6A3A),
  trim: Color(0xFFE8B04A),
  hairStyle: HairStyle.short,
);

const taalLook = AvatarLook(
  skin: Color(0xFFC08A66),
  hair: Color(0xFF1C1014),
  top: Color(0xFFD9335A), // dance red
  bottom: Color(0xFF231426),
  shoe: Color(0xFFFFE9C2),
  trim: Color(0xFFFFD23F),
  hairStyle: HairStyle.tied,
  sleeves: false,
  longLegs: true,
);

const cricketLook = AvatarLook(
  skin: Color(0xFFB37B58),
  hair: Color(0xFF17120F),
  top: Color(0xFFF1EEE4), // gully whites
  bottom: Color(0xFFE2DED2),
  shoe: Color(0xFFFFFFFF),
  trim: Color(0xFF00C2B8),
  hairStyle: HairStyle.crop,
  sleeves: false,
);

const lumenLook = AvatarLook(
  skin: Color(0xFFCB9A78),
  hair: Color(0xFF2A2F3A),
  top: Color(0xFFD7E3EE), // habitat suit
  bottom: Color(0xFF9FB2C6),
  shoe: Color(0xFF5E6E82),
  trim: Color(0xFF7FD8FF),
  hairStyle: HairStyle.short,
);

/// The look for a game id (the Neon Slice jacket for anything unknown).
AvatarLook lookFor(String gameId) => switch (gameId) {
  'mirror-mela' => melaLook,
  'pataka-pose' => patakaLook,
  'craftguard' => duelLook,
  'taal-toofan' => taalLook,
  'tapeball' => cricketLook,
  'lumen' => lumenLook,
  _ => sliceLook,
};
