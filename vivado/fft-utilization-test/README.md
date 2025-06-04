This is a Vivado project and script to generate utilization report for different combinations of generics.

1. Open the project
2. In Vivado tcl console run:
```
cd [get_property directory [current_project]]
source get_utilization.tcl
util_batch
``` 
3. Results will appear in reports folder
