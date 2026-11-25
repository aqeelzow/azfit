import json, pathlib
# The exercise library's source. Run `python3 docs/library/draft.py` after editing: it writes the JSON the
# app loads (AZKit/Sources/AZModel/Resources/exercises.json) and the review page (docs/library/review.md).
root = pathlib.Path(__file__).resolve().parents[2]
out = root / "docs/library"
json_out = root / "AZKit/Sources/AZModel/Resources/exercises.json"

# group, id, name, minimum sets/week to grow, most sets/week you recover from, hours to recover
muscles = [
 ("chest","upper_chest","Upper chest",4,12,48),
 ("chest","lower_chest","Mid and lower chest",6,18,48),
 ("back","lats","Lats",8,20,48),
 ("back","upper_back","Upper back (rhomboids, mid traps)",6,20,48),
 ("back","traps","Upper traps",0,20,36),
 ("back","lower_back","Lower back",0,10,72),
 ("shoulders","front_delts","Front delts",0,12,48),
 ("shoulders","side_delts","Side delts",8,26,36),
 ("shoulders","rear_delts","Rear delts",6,24,36),
 ("arms","biceps","Biceps",6,20,36),
 ("arms","triceps","Triceps",6,18,48),
 ("arms","forearms","Forearms and grip",0,16,24),
 ("core","abs","Abs",0,20,24),
 ("core","obliques","Obliques",0,16,24),
 ("legs","quads","Quads",8,20,72),
 ("legs","hamstrings","Hamstrings",6,18,72),
 ("legs","glutes","Glutes",4,16,60),
 ("legs","adductors","Inner thighs (adductors)",0,12,48),
 ("legs","abductors","Outer hips (abductors)",0,12,36),
 ("legs","calves","Calves",8,20,24),
]
groups = {"chest":"Chest","back":"Back","shoulders":"Shoulders","arms":"Arms","core":"Core","legs":"Legs"}

H,V,HP,VP,SQ,HI,LU,IS,CO,CA = "horizontal_push","vertical_push","horizontal_pull","vertical_pull","squat","hinge","lunge","isolation","core","carry"
def m(s):  # "quads 1, glutes .5"
    return {k: float(v) for k, v in (x.split() for x in s.split(","))}
# id, name, pattern, equipment, fatigue 1-5, joints it loads hard, muscles with share of the work
E = [
 # chest
 ("barbell_bench_press","Barbell bench press",H,"barbell",4,"shoulder elbow wrist","lower_chest 1, upper_chest .5, front_delts .5, triceps .5"),
 ("incline_barbell_press","Incline barbell press",H,"barbell",4,"shoulder elbow","upper_chest 1, lower_chest .5, front_delts .5, triceps .5"),
 ("decline_barbell_press","Decline barbell press",H,"barbell",3,"elbow","lower_chest 1, triceps .5, front_delts .25"),
 ("close_grip_bench_press","Close-grip bench press",H,"barbell",3,"elbow wrist","triceps 1, lower_chest .5, front_delts .5"),
 ("dumbbell_bench_press","Dumbbell bench press",H,"dumbbell",3,"shoulder","lower_chest 1, upper_chest .5, front_delts .5, triceps .5"),
 ("incline_dumbbell_press","Incline dumbbell press",H,"dumbbell",3,"shoulder","upper_chest 1, lower_chest .5, front_delts .5, triceps .5"),
 ("machine_chest_press","Machine chest press",H,"machine",2,"","lower_chest 1, front_delts .5, triceps .5"),
 ("incline_machine_press","Incline machine press",H,"machine",2,"","upper_chest 1, front_delts .5, triceps .5"),
 ("smith_incline_press","Smith machine incline press",H,"smith",3,"shoulder","upper_chest 1, lower_chest .5, front_delts .5, triceps .5"),
 ("push_up","Push-up",H,"bodyweight",2,"wrist","lower_chest 1, front_delts .5, triceps .5, abs .25"),
 ("weighted_dip","Dip",H,"bodyweight",3,"shoulder elbow","lower_chest 1, triceps 1, front_delts .5"),
 ("cable_fly","Cable fly",IS,"cable",2,"shoulder","lower_chest 1, upper_chest .5, front_delts .25"),
 ("low_to_high_cable_fly","Low-to-high cable fly",IS,"cable",2,"","upper_chest 1, front_delts .25"),
 ("dumbbell_fly","Dumbbell fly",IS,"dumbbell",2,"shoulder","lower_chest 1, upper_chest .5"),
 ("pec_deck","Pec deck",IS,"machine",1,"","lower_chest 1, upper_chest .5"),
 # shoulders
 ("overhead_press","Standing overhead press",V,"barbell",4,"shoulder lower_back","front_delts 1, side_delts .5, triceps .5, upper_chest .25, abs .25"),
 ("seated_dumbbell_press","Seated dumbbell shoulder press",V,"dumbbell",3,"shoulder","front_delts 1, side_delts .5, triceps .5"),
 ("machine_shoulder_press","Machine shoulder press",V,"machine",2,"","front_delts 1, side_delts .5, triceps .5"),
 ("arnold_press","Arnold press",V,"dumbbell",3,"shoulder","front_delts 1, side_delts .5, triceps .5"),
 ("landmine_press","Landmine press",V,"barbell",2,"","front_delts 1, upper_chest .5, triceps .5, obliques .25"),
 ("dumbbell_lateral_raise","Dumbbell lateral raise",IS,"dumbbell",1,"shoulder","side_delts 1, traps .25"),
 ("cable_lateral_raise","Cable lateral raise",IS,"cable",1,"","side_delts 1"),
 ("machine_lateral_raise","Machine lateral raise",IS,"machine",1,"","side_delts 1"),
 ("cable_upright_row","Cable upright row",IS,"cable",2,"shoulder wrist","side_delts 1, traps .5, front_delts .25"),
 ("dumbbell_front_raise","Dumbbell front raise",IS,"dumbbell",1,"","front_delts 1"),
 ("rear_delt_fly","Bent-over rear delt fly",IS,"dumbbell",1,"","rear_delts 1, upper_back .25"),
 ("reverse_pec_deck","Reverse pec deck",IS,"machine",1,"","rear_delts 1, upper_back .25"),
 ("cable_rear_delt_fly","Cable rear delt fly",IS,"cable",1,"","rear_delts 1"),
 ("face_pull","Face pull",HP,"cable",1,"","rear_delts 1, upper_back .5, traps .25"),
 # back
 ("deadlift","Deadlift",HI,"barbell",5,"lower_back hip","glutes 1, hamstrings 1, lower_back 1, quads .5, traps .5, forearms .5, upper_back .25, lats .25"),
 ("pull_up","Pull-up",VP,"bodyweight",3,"shoulder elbow","lats 1, upper_back .5, biceps .5, rear_delts .25, forearms .25"),
 ("chin_up","Chin-up",VP,"bodyweight",3,"elbow","lats 1, biceps 1, upper_back .5, forearms .25"),
 ("assisted_pull_up","Assisted pull-up",VP,"machine",2,"","lats 1, upper_back .5, biceps .5"),
 ("lat_pulldown","Lat pulldown",VP,"cable",2,"","lats 1, upper_back .5, biceps .5, rear_delts .25"),
 ("close_grip_pulldown","Close-grip pulldown",VP,"cable",2,"","lats 1, biceps .5, upper_back .25"),
 ("single_arm_pulldown","Single-arm cable pulldown",VP,"cable",1,"","lats 1, biceps .25"),
 ("straight_arm_pulldown","Straight-arm pulldown",IS,"cable",1,"","lats 1, triceps .25"),
 ("barbell_row","Barbell row",HP,"barbell",4,"lower_back","upper_back 1, lats 1, rear_delts .5, biceps .5, lower_back .5, forearms .25"),
 ("pendlay_row","Pendlay row",HP,"barbell",4,"lower_back","upper_back 1, lats 1, rear_delts .5, biceps .5, lower_back .5"),
 ("dumbbell_row","One-arm dumbbell row",HP,"dumbbell",2,"","lats 1, upper_back 1, biceps .5, rear_delts .25"),
 ("chest_supported_row","Chest-supported row",HP,"dumbbell",2,"","upper_back 1, lats .5, rear_delts .5, biceps .5"),
 ("seated_cable_row","Seated cable row",HP,"cable",2,"","upper_back 1, lats 1, biceps .5, rear_delts .25"),
 ("t_bar_row","T-bar row",HP,"barbell",3,"lower_back","upper_back 1, lats 1, rear_delts .5, biceps .5, lower_back .25"),
 ("machine_row","Machine row",HP,"machine",2,"","upper_back 1, lats .5, rear_delts .5, biceps .5"),
 ("seal_row","Seal row",HP,"barbell",3,"","upper_back 1, lats 1, rear_delts .5, biceps .5"),
 ("inverted_row","Inverted row",HP,"bodyweight",2,"","upper_back 1, lats .5, rear_delts .5, biceps .5"),
 ("rack_pull","Rack pull",HI,"barbell",4,"lower_back","traps 1, upper_back 1, lower_back 1, glutes .5, forearms .5"),
 ("barbell_shrug","Barbell shrug",IS,"barbell",2,"","traps 1, forearms .5"),
 ("dumbbell_shrug","Dumbbell shrug",IS,"dumbbell",2,"","traps 1, forearms .5"),
 ("back_extension","Back extension",HI,"bodyweight",2,"","lower_back 1, glutes 1, hamstrings .5"),
 ("good_morning","Good morning",HI,"barbell",4,"lower_back","hamstrings 1, lower_back 1, glutes .5"),
 # arms
 ("barbell_curl","Barbell curl",IS,"barbell",1,"elbow wrist","biceps 1, forearms .5"),
 ("ez_bar_curl","EZ-bar curl",IS,"ez_bar",1,"elbow","biceps 1, forearms .5"),
 ("dumbbell_curl","Dumbbell curl",IS,"dumbbell",1,"","biceps 1, forearms .25"),
 ("hammer_curl","Hammer curl",IS,"dumbbell",1,"","biceps 1, forearms 1"),
 ("incline_dumbbell_curl","Incline dumbbell curl",IS,"dumbbell",1,"","biceps 1"),
 ("preacher_curl","Preacher curl",IS,"ez_bar",1,"elbow","biceps 1"),
 ("cable_curl","Cable curl",IS,"cable",1,"","biceps 1, forearms .25"),
 ("reverse_curl","Reverse curl",IS,"ez_bar",1,"wrist","forearms 1, biceps .5"),
 ("wrist_curl","Wrist curl",IS,"dumbbell",1,"wrist","forearms 1"),
 ("triceps_pushdown","Triceps pushdown",IS,"cable",1,"","triceps 1"),
 ("overhead_cable_extension","Overhead cable triceps extension",IS,"cable",1,"elbow","triceps 1"),
 ("skull_crusher","Skull crusher",IS,"ez_bar",2,"elbow","triceps 1"),
 ("overhead_dumbbell_extension","Overhead dumbbell extension",IS,"dumbbell",1,"elbow shoulder","triceps 1"),
 ("dumbbell_kickback","Dumbbell kickback",IS,"dumbbell",1,"","triceps 1"),
 ("bench_dip","Bench dip",IS,"bodyweight",1,"shoulder","triceps 1, front_delts .25"),
 # legs
 ("back_squat","Back squat",SQ,"barbell",5,"knee hip lower_back","quads 1, glutes 1, adductors .5, lower_back .5, hamstrings .25"),
 ("front_squat","Front squat",SQ,"barbell",5,"knee wrist","quads 1, glutes .5, adductors .5, upper_back .5, abs .25"),
 ("smith_squat","Smith machine squat",SQ,"smith",3,"knee","quads 1, glutes .5, adductors .25"),
 ("hack_squat","Hack squat",SQ,"machine",3,"knee","quads 1, glutes .5, adductors .25"),
 ("pendulum_squat","Pendulum squat",SQ,"machine",3,"knee","quads 1, glutes .5"),
 ("belt_squat","Belt squat",SQ,"machine",3,"knee","quads 1, glutes .5, adductors .5"),
 ("leg_press","Leg press",SQ,"machine",3,"knee","quads 1, glutes .5, adductors .5"),
 ("goblet_squat","Goblet squat",SQ,"dumbbell",2,"","quads 1, glutes .5, adductors .5, abs .25"),
 ("bulgarian_split_squat","Bulgarian split squat",LU,"dumbbell",3,"knee","quads 1, glutes 1, adductors .5"),
 ("walking_lunge","Walking lunge",LU,"dumbbell",3,"knee","quads 1, glutes 1, adductors .5"),
 ("reverse_lunge","Reverse lunge",LU,"dumbbell",2,"","glutes 1, quads 1, adductors .5"),
 ("step_up","Step-up",LU,"dumbbell",2,"knee","quads 1, glutes 1"),
 ("leg_extension","Leg extension",IS,"machine",1,"knee","quads 1"),
 ("romanian_deadlift","Romanian deadlift",HI,"barbell",4,"lower_back","hamstrings 1, glutes 1, lower_back .5, adductors .5, forearms .25"),
 ("dumbbell_romanian_deadlift","Dumbbell Romanian deadlift",HI,"dumbbell",3,"lower_back","hamstrings 1, glutes 1, lower_back .5, adductors .25"),
 ("stiff_leg_deadlift","Stiff-leg deadlift",HI,"barbell",4,"lower_back","hamstrings 1, glutes .5, lower_back .5"),
 ("single_leg_rdl","Single-leg Romanian deadlift",HI,"dumbbell",2,"","hamstrings 1, glutes 1, abductors .25"),
 ("trap_bar_deadlift","Trap bar deadlift",HI,"trap_bar",4,"hip","quads 1, glutes 1, hamstrings .5, lower_back .5, traps .5, forearms .5"),
 ("sumo_deadlift","Sumo deadlift",HI,"barbell",5,"hip","glutes 1, adductors 1, quads .5, hamstrings .5, lower_back .5, traps .5, forearms .5"),
 ("lying_leg_curl","Lying leg curl",IS,"machine",1,"","hamstrings 1, calves .25"),
 ("seated_leg_curl","Seated leg curl",IS,"machine",1,"","hamstrings 1"),
 ("nordic_curl","Nordic curl",IS,"bodyweight",3,"knee","hamstrings 1"),
 ("hip_thrust","Barbell hip thrust",HI,"barbell",3,"","glutes 1, hamstrings .5, quads .25"),
 ("glute_bridge","Glute bridge",HI,"bodyweight",1,"","glutes 1, hamstrings .5"),
 ("cable_pull_through","Cable pull-through",HI,"cable",2,"","glutes 1, hamstrings .5"),
 ("cable_kickback","Cable glute kickback",IS,"cable",1,"","glutes 1"),
 ("kettlebell_swing","Kettlebell swing",HI,"kettlebell",3,"lower_back","glutes 1, hamstrings 1, lower_back .5, forearms .25"),
 ("hip_abduction","Hip abduction machine",IS,"machine",1,"","abductors 1, glutes .25"),
 ("hip_adduction","Hip adduction machine",IS,"machine",1,"","adductors 1"),
 ("standing_calf_raise","Standing calf raise",IS,"machine",1,"ankle","calves 1"),
 ("seated_calf_raise","Seated calf raise",IS,"machine",1,"","calves 1"),
 ("leg_press_calf_raise","Calf press on leg press",IS,"machine",1,"","calves 1"),
 # core and carries
 ("hanging_leg_raise","Hanging leg raise",CO,"bodyweight",2,"","abs 1, obliques .5, forearms .25"),
 ("cable_crunch","Cable crunch",CO,"cable",1,"","abs 1"),
 ("ab_wheel","Ab wheel rollout",CO,"bodyweight",2,"lower_back","abs 1, obliques .5, lats .25"),
 ("crunch","Crunch",CO,"bodyweight",1,"","abs 1"),
 ("decline_sit_up","Decline sit-up",CO,"bodyweight",1,"","abs 1"),
 ("dead_bug","Dead bug",CO,"bodyweight",1,"","abs 1"),
 ("plank","Plank",CO,"bodyweight",1,"","abs 1, obliques .5"),
 ("side_plank","Side plank",CO,"bodyweight",1,"","obliques 1, abs .25"),
 ("pallof_press","Pallof press",CO,"cable",1,"","obliques 1, abs .5"),
 ("cable_woodchop","Cable woodchop",CO,"cable",1,"","obliques 1, abs .5"),
 ("farmers_carry","Farmer's carry",CA,"dumbbell",3,"","forearms 1, traps 1, abs .5, obliques .5, glutes .25"),
 ("suitcase_carry","Suitcase carry",CA,"dumbbell",2,"","obliques 1, forearms 1, traps .5"),
]
ids = {x[1] for x in muscles}
seen = set()
exercises = []
for (i, name, pat, eq, fat, joints, ms) in E:
    assert i not in seen, i; seen.add(i)
    mm = m(ms); assert set(mm) <= ids, (i, set(mm) - ids)
    exercises.append(dict(id=i, name=name, pattern=pat, equipment=eq, fatigue_cost=fat,
                          joint_stress=joints.split(), muscles=mm))
data = dict(version=1, status="draft",
  muscle_groups=[dict(id=g, name=n, muscles=[x[1] for x in muscles if x[0]==g]) for g,n in groups.items()],
  muscles=[dict(id=x[1], group=x[0], name=x[2], min_sets_per_week=x[3], max_recoverable_sets_per_week=x[4], recovery_hours=x[5]) for x in muscles],
  exercises=exercises)
json.dump(data, open(json_out,"w"), indent=1)

# review page
mname = {x[1]: x[2].split(" (")[0] for x in muscles}
mgroup = {x[1]: x[0] for x in muscles}
frac = {1.0:"", .5:" ½", .25:" ¼"}
L = ["# Exercise library: draft for review", "",
 f"{len(exercises)} exercises, {len(muscles)} muscles in {len(groups)} groups. Generated by [draft.py](draft.py), which also writes `AZKit/Sources/AZModel/Resources/exercises.json`.", "",
 "How to read it:", "",
 "- **Works**: the muscles one set counts toward. No mark means a full set, ½ half a set, ¼ a quarter. So one set of bench press counts as a full set for mid chest and half a set each for upper chest, front delts and triceps.",
 "- **Fatigue**: how much a hard set takes out of you overall, 1 (curl) to 5 (heavy deadlift or squat). Div uses it to decide what fits in a session and when to deload.",
 "- **Joints**: joints the lift loads hard, so Div can swap around a sore one.", "",
 "Mark anything wrong, missing, or that your gym doesn't have.", "",
 "## Muscles and starting numbers", "",
 "Min and max are sets per week: below min does little, above max is more than most people recover from. Div adjusts both per person from how you respond. Recovery is roughly how long one hard session takes to clear.", "",
 "| Group | Muscle | Min sets | Max sets | Recovery |", "|---|---|---|---|---|"]
for g, n in groups.items():
    for x in [x for x in muscles if x[0]==g]:
        L.append(f"| {n} | {x[2]} | {x[3]} | {x[4]} | {x[5]} h |")
for g, n in groups.items():
    rows = [e for e in exercises if mgroup[max(e["muscles"], key=lambda k: (e["muscles"][k], -list(e["muscles"]).index(k)))]==g]
    if not rows: continue
    L += ["", f"## {n}", "", "| Exercise | Works | Fatigue | Joints |", "|---|---|---|---|"]
    for e in rows:
        works = ", ".join(mname[k]+frac[v] for k, v in e["muscles"].items())
        L.append(f"| {e['name']} | {works} | {e['fatigue_cost']} | {', '.join(j.replace('_',' ') for j in e['joint_stress']) or '-'} |")
open(out/"review.md","w").write("\n".join(L)+"\n")
print(len(exercises), "exercises")
