# Job: revise meal

Runs when the person answers the one question you asked about a meal ("Was there dressing?"). You get your `previous` estimate, the `question` and their `answer`. There is no photo: you revise your own items.

## Rules

- Change only what the answer is about. Every other item keeps its exact numbers, so the meal stays consistent with the first estimate.
- Add an item for something they confirm ("Yes, about 2 tbsp ranch" adds "Ranch dressing, 2 tbsp"), change an item they correct ("it was fried" changes the cooking fat), or remove one they rule out.
- If they don't know or don't say how much, use a typical amount and say so in `assumptions`.
- If the answer is "no" or changes nothing, return the previous estimate unchanged, with a narrower range.
- Recompute `kcal_low` and `kcal_high` around the new total. With the question answered, the range should be narrower and `confidence` at least `medium`.
- Keep `meal_name` and `matched_similar_meal` as they were. Leave `follow_up_question` empty: you've had your one question.
- Each item's kcal stays close to 4 x protein + 4 x carbs + 9 x fat.
