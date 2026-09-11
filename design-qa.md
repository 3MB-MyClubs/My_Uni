# Event Detail Design QA

**Comparison target**

- Source visual truth: Figma `ClubUp-Desings` (`26to4mshypDnnmrCeorZFf`), frames `Event new design light` (`283:381`, `402 × 1778` px, canvas x 14462 / y 27569) and `Event new design black` (`283:497`, `402 × 1754` px, canvas x 14895 / y 27569). Both pulled at native size via `get_screenshot`, plus `get_design_context` on `283:410` / `283:526` (content), `283:400` / `283:516` (header actions) and `656:4` / `656:12` (hero fade) for exact tokens.
- Implementation capture: a scratch widget golden at `402 × 2200` logical px in both themes, with the bundled Figtree weights and the engine's `MaterialIcons-Regular.otf` loaded so text and icons render for real rather than as Ahem boxes. The scratch test was deleted after the comparison; the retained layout golden is `design-qa-implementation.png` (`374 × 609` px, Ahem, dark, scrolled to `maxScrollExtent`) from `test/event_social_visual_qa_test.dart`.
- Viewport: the frames' own `402` logical px for visual comparison; responsive coverage at `393 × 852` in `test/event_detail_new_design_test.dart`.
- The two frames are structurally identical — same node names, same order — so one widget tree serves both themes off `ClubUpColors`' theme-aware getters.
- State: upcoming event, four tags, one speaker with a LinkedIn address, two programme sessions, an external registration link, student session.

**Deliberate departures from the frames** (each agreed with the user before building)

- **Accent.** The frames paint `#1DA1F2` on the time badge, the leading tag, the timeline dots and the CTA. That blue is a leftover from the Figma template — as in every earlier area of this handoff — so the burgundy `ClubUpColors.accent` (`#800020`) is used throughout, with `accentText` (`#E8A1A6`) in dark where `#800020` fails contrast on a `#1E1E1E` card.
- **Tag colour is positional.** The frames tint "Music" with the accent and "21+" rose `#FA526B`. Real `Event.tags` are free text, so the leading chip — which reads as the event's category — takes the accent and every other chip is neutral. A keyword list would only ever match English tags.
- **Sections the frames omit are kept**: the Follow pill on the host row, the LIVE / ENDED status pill and the audience badge on the hero, the delete action in the header, the "Bring friends" quick-invite row, and the floating RSVP / Add-to-calendar / Remind-me bar. The frames leave `pb-120px` of clearance under the last section, which is exactly the room that bar needs.
- **Speaker LinkedIn chip in both themes.** The light frame wraps the address in a bordered chip; the dark frame leaves it a bare row with a 2px inner gap. This is the only place the two frames disagree, and the chip is the finished treatment.
- **24-hour session times.** The frames read `7:00 PM`; the app formats event times as `19:00` and Turkish is a 24-hour locale.
- **Title weight w800, not w900.** The frames set Figtree Black; only 400–800 are bundled, and Flutter resolves w900 to ExtraBold anyway. Adding `Figtree-Black.ttf` is the open follow-up if the true Black is wanted.
- **LinkedIn glyph.** Material ships no brand mark and the project carries no SVG loader, so the chip uses `Icons.business_center_outlined` — the same stand-in the event wizard already settled on for this field in this handoff.

**Findings**

- No actionable P0, P1 or P2 differences remain.
- Typography: the 34px/1.1 title, 18px ExtraBold section heads, 15px/1.6 about copy, 13px Bold chips, 16px ExtraBold speaker names, 15px ExtraBold session titles and the 14px Bold "Registration" label all match the frames, in Figtree.
- Spacing and rhythm: `scrollable-content` is reproduced as one 20px column on a uniform 32px gap with hairlines as members of that rhythm — verified by measurement, not by eye (`a section rule is 32px clear of the content on both sides`). Speakers → programme → registration run divider-free, matching the frames, whose last `Line` node is `283:455`.
- Hero: height now scales as `width × 1.0448` (the frames' 420/402) rather than the old `(width − 40) × 0.9`, the top scrim is a 100px band instead of a full-height wash, and `hero-bottom-fade` dissolves the last 140px into the page colour in both themes.
- Header actions are genuinely theme-dependent: a near-opaque `rgba(255,255,255,0.7)` disc behind an 8px blur with a `#18181B` glyph in light, the dim `rgba(255,255,255,0.2)` disc with a white glyph in dark.
- Colours: `ClubUpColors` already carried this design's exact neutrals (`#FAF9F6`/`#121212` page, `#FFFFFF`/`#1E1E1E` card, `#18181B`/`#FAFAFA` text, `#71717A`/`#A1A1AA` muted, `#F4F4F5` chip), so no new palette class was needed. The one divergence — dark hairline `#2D2D2D` vs the frames' `#27272A` — was left alone deliberately: `ClubUpColors` is shared with Search, Events and Home, and the two greys are indistinguishable.
- Asset fidelity: the screen's only raster is the event cover, which keeps resolving through the shared `EventCoverImage` fallback chain. Everything else is Material iconography.
- Scope: `ClubEventAdminScreen` and the widgets it shares (`_SpeakersRow`, `_ProgrammeTimeline`, `_RegistrationCard`, `_TicketCard`, `_Tag`) were not restyled — the new frames got student-local copies (`_EventSpeakerCards`, `_EventProgramme`, `_EventRegistrationCta`), the call this file already made for `_EventTag` vs `_Tag`.

**Comparison history**

- Pass 1 rendered the whole column correctly but showed a doubled hairline around an empty band between the host row and "About the event".
- Cause: the attendee section collapses to `SizedBox.shrink()` whenever the viewer can see no attendees — which is every session without Supabase, guest mode included, because `fetchEventAttendees` returns `const []` and sets `_remoteAttendeesLoaded` with nothing in it — while its section rule kept drawing beside it.
- Fix: the rule moved *inside* the `ListenableBuilder` and the whole rule-plus-card returns `SizedBox.shrink()` when `EventAttendeeVisibility.isEmpty`.
- Post-fix evidence: the re-shot light and dark captures show host → rule → about with a single hairline, and the section order, hero, title, CTA and rhythm assertions all pass.

**Implementation checklist**

- [x] Section order reproduced: title, host, who is going, about, tags, speakers, programme, bring friends, registration.
- [x] Uniform 32px rhythm with hairlines as members of it.
- [x] Hero height, 100px top scrim and the 140px bottom fade into the page colour.
- [x] Theme-dependent header discs.
- [x] Time badge, location tile, tag chips, attendee chip, speaker card, session rows and the 56px "Reserve My Spot" CTA.
- [x] Attendee avatars at five 32px discs on a 22px step.
- [x] English/Turkish localization (`programmeSchedule`, `reserveMySpot` added to both ARBs and regenerated).
- [x] Six focused widget tests, regenerated layout golden, `dart analyze lib test` clean.
- [x] Every suite that pumps `EventDetailScreen` or `ClubEventAdminScreen` re-run — 45 pass, 2 fail (both pre-existing, see below): `club_profile_event_filters`, `event_detail_host_layout`, `event_detail_new_design`, `event_social_sections`, `event_social_visual_qa`, `guest_screen_smoke`, `shared_event_message_card`, plus `content_audience_store` for the ARB additions.
- [x] Every event-related failure confirmed pre-existing by re-running the same file at `2a936-` in a baseline worktree: `shared_event_message_card` (2 fail both trees), `event_share_visual_qa` (2 both), `event_attendance_privacy` (1 both).
- [x] A *full*-suite side-by-side parity run could not be completed — this machine kills `flutter test` for memory while a `flutter run` is live, at concurrency 4 as well as at the default, and twice over. The furthest partial run reached **562 pass / 44 fail**; every failure in it sits in the chat / club / admin / profile files that this change cannot reach, and a sample of four of them (`chat_store`, `club_profile_smoke`, `club_insights_screen`, `admin_messaging_ui_guards`) scores an identical **20 pass / 16 fail** in both trees. Note two files in the working tree — `lib/widgets/home_design.dart` and `test/home_design_test.dart` — belong to a concurrent session, not to this change.

**Follow-up polish**

- `Figtree-Black.ttf` (weight 900) would let the title render at the frames' true weight; it is not bundled today.
- The attendee section still cannot be widget-tested on this screen (the Supabase path documented above). Its rendering is covered through `ThisWeekScreen` in `test/event_social_sections_test.dart`.

final result: passed
