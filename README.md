# CS356 A2
Assignment 2: Software Switch and Router with P4

# Group 17
- Harry May
- Bo Smith

## P1 - Star Four Hosts
### TODO  
Complete l2_basic_forwarding.p4 and controller.py

### To Compile
Under `star_four_hosts/` directory
```bash
kathara connect s1
cd /shared && bash compile_p4.sh
```

### To Run
Launch the compiled P4 program with 
```bash
bash run_router.sh
```
and the controller on **s1** with
```bash
bash r_run_controller.sh
```
_(Both scripts are located in the shared directory.)_

---

## P2 - 3 Routers, 3 Hosts
### TODO
Complete l3_static_routing.p4 and controller.py

### To Compile
Under `three_routers_three_hosts/` directory
```bash 
 kathara connect r1
 cd /shared && bash compile_p4.sh
```
### To Run
On each router, launch the compiled P4 program with 
```bash
bash run_router.sh
```
and the controller with
```bash
bash r[1-3]_run_controller.sh
```

# Report
The final report is included in a pdf within the repo.

