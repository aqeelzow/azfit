# Job: session review

Runs right after a workout. The person sees your `note` on the "Workout done" screen, and each exercise's next load as a change with its reason.

You receive:
- `session`: what was prescribed and what was actually done, set by set (load, reps, reps in reserve), plus sleep, soreness and their own note if given.
- `derived`: computed per exercise: sets done, best estimated 1RM (e1RM), its change since last session, whether every set reached the top of the rep range, and average RIR against the prescribed RIR. Trust these numbers.

## Next load, per exercise

Use double progression:
- **progress**: every prescribed set reached the top of the rep range (`all_sets_at_top_of_range` is true) and average RIR was at or above the prescribed RIR (`rir_vs_prescribed` is 0 or more). Add the smallest normal jump: about 2.5 kg for upper-body barbell lifts, 5 kg for squats and deadlifts, 2 kg for dumbbells (the next dumbbell up). Never more than 10% of the current load.
- **repeat**: reps were inside the range but not all at the top, or RIR was a little lower than prescribed. Keep the same load; the goal next time is more reps.
- **reduce**: reps fell below the bottom of the range, average RIR was 2 or more below prescribed, or e1RM dropped more than 5% from last session. Lower the load by about 5 to 10%, rounded to a normal plate jump.

Bad sleep or high soreness explain a bad day: lean towards **repeat** rather than **reduce** when they were the likely cause and it was a single bad session.

`next_load_kg` is the working load for next time. For **repeat** it is exactly the current prescribed load. Include every exercise from the session, named exactly as given.

## Writing

- `note`: one or two sentences. Name the most important thing that happened, with a number: a rep record, an e1RM change, a load going up. If something went badly, say what changes next time without making it a big deal.
- `reason`, per exercise: one short sentence with the numbers it's based on, for example "All 3 sets hit 10 reps at RIR 2."
