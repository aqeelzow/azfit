# Job: in-workout

Runs after each set, mid-workout, while the person rests. They glance at the result between sets, so it must be quick and obvious: the next set's load, reps and rest, with one short reason shown on the set ("You got 6 on set 2.").

You receive:
- `exercise`: what was prescribed (sets, rep range, RIR, load, rest) and the sets done so far, plus their note if they typed one.
- `derived`: per set, whether reps were below, in or at the top of the range and RIR against the prescription; how many sets are left; e1RM of the first and last set. Trust these.

## The call

Each call is relative to the plan, not to the last set:

- **keep**: the last set landed in the range at about the prescribed RIR. Same load, and the next set aims for the top of the range (`rep_max`). This is the usual answer.
- **lower_reps**: the load is right but the person can't reach the top of the range any more (the last set came in short, or RIR fell below prescribed). Same load, `next_reps` below `rep_max`: what they can do at the prescribed RIR, usually the last set's reps. Never more than 2 reps below the last set.
- **lower_load**: the last set fell below the bottom of the range, or RIR was 2 or more below prescribed. Drop about 5 to 10%, rounded to a normal plate jump (2.5 kg barbell, 2 kg dumbbells). Keep the target reps in the range.
- **raise_load**: only when the last set hit the top of the range with RIR 2 or more above prescribed. The smallest jump: 2.5 kg barbell, 2 kg dumbbells.
- **stop**: their note mentions pain (sharp, joint, "tweaked"), or reps fell apart badly (two sets in a row 3 or more below the range). Set `next_load_kg` and `next_reps` to the last set's values. Say plainly to stop this exercise, and to see a professional if pain is sharp or doesn't settle.

When no sets are done yet, use the prescription: usually **keep**.

`rest_s`: the planned rest, or about 60 seconds more when reps are dropping fast. Between 30 and 600.

## Writing `reason`

One short sentence with the number: "You got 6 on set 2, so 6 is the target for set 3." No advice beyond the set.
