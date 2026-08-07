# AlarmApp sound pack

License bar: CC0 / public domain only.

All source recordings are from [BigSoundBank](https://bigsoundbank.com/) (Joseph Sardin), released under [CC0 1.0 Universal](https://bigsoundbank.com/licenses.html). Converted to mono IMA4 CAF (`afconvert -f caff -d ima4`) for `UNNotificationSound(named:)` — notification-friendly size, ≤30s. No Apple system UISounds.

| id | file | source URL | license | duration |
|---|---|---|---|---|
| classic_bell | classic_bell.caf | https://bigsoundbank.com/church-bell-s0135.html | CC0 | 0:17 |
| digital_beep | digital_beep.caf | https://bigsoundbank.com/digital-watch-beep-1-s2254.html | CC0 | ~0.4s |
| mechanical_ring | mechanical_ring.caf | https://bigsoundbank.com/mechanical-alarm-clock-long-ring-2-s1375.html | CC0 | 0:13 |
| electronic_buzz | electronic_buzz.caf | https://bigsoundbank.com/electronic-alarm-buzzer-1-s0035.html | CC0 | 0:22 |
| soft_chime | soft_chime.caf | https://bigsoundbank.com/2-pendulum-chimes-s3361.html | CC0 | 0:16 |
| radar_pulse | radar_pulse.caf | https://bigsoundbank.com/sonar-2-s1920.html | CC0 | 0:21 |

## Character notes

| id | Intended character | Actual source (honest) |
|---|---|---|
| classic_bell | bell / chime | Outdoor church bell (with faint birdsong) |
| digital_beep | short digital beep | Digital watch beep (~0.4 s) |
| mechanical_ring | mechanical alarm ring | Mechanical alarm clock, long ring #2 |
| electronic_buzz | electronic buzzer | Electronic alarm (buzzer) #1 |
| soft_chime | soft chime | Two pendulum clock chimes |
| radar_pulse | repeating pulse | Synthetic active sonar pulses (closest CC0 repeating pulse; not a radar UI tone) |

`default` has no bundled file (system notification sound).
