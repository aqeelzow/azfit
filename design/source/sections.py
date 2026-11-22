"""The screen list, in app order. Shared by build.py (gallery) and canvas.py (artifact canvas)."""

SECTIONS = [
  ('Onboarding', [('Welcome','Welcome'),('Goal','Goal'),('Days','Training days'),('Connect','Connect Div')]),
  ('Today and training', [('Home','Home'),('QuickAdd','Quick add'),('Train','This week'),('Workout','Live workout'),('Done','Workout complete'),('Library','Swap exercise'),('Exercise','Exercise detail')]),
  ('Div', [('Coach','Chat'),('Voice','Voice'),('Review',"Div's log"),('Memory','What Div knows')]),
  ('Eat', [('Eat','Eat'),('Snap','Snap a meal'),('Meal','Meal estimate'),('Calibrate','Why 2,350?')]),
  ('Body', [('Body','Muscle map'),('Scan','Body scan'),('ScanResult','Scan result'),('Progress','Progress')]),
]
INTER = {'Goal','Days','Workout','Exercise','Coach','Review','Memory','Meal','Calibrate'}
