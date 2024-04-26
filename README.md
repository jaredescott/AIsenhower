# AIsenhower
## Description
This Julia app displays all of a user's incomplete tasks from the AI planning website [Reclaim.ai](https://app.reclaim.ai), organizing them in an urgent-important matrix based on Reclaim's Priorities feature. Tasks with priorities 1-4 are displayed as follows:

  > Priority 1 - Urgent, Important<br>
  > Priority 2 - Not Urgent, but Important<br>
  >  Priority 3 - Urgent, but Not Important<br>
  > Priority 4 - Not Urgent, Not Important<br>
  
## Usage Notes
 - Before running the Julia script, obtain an API key from https://app.reclaim.ai/settings/developer and copy it into the `API_KEY` variable at the top of the script.
 - Run "AIsenhower.jl" to open the app.
 - When running the script for the first time, type "y" into the terminal/REPL when prompted to install dependencies.
 - Clicking on a task will open the task in the default browser.