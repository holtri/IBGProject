;############## extensions ##############
extensions [a-star-nlogo]

;############## variables ##############
breed [exits exit]
breed [commuters commuter]
breed [entries entry]
breed [train-doors train-door]

commuters-own[exit-path stuck-count direction enqueued target-door speed speed-count born-tick stuck-count-by-direction]
patches-own[spawn-point obstacle entry-point pdirection]
exits-own[exit-queue]
train-doors-own[direction exit-queue t-timer open? number-of-arrivals]
entries-own[tta]

globals [
  standard-deviation-train-arrival
  time-reserved-for-disembark
  speed-level
  speed-level-percentage
  total-stuck-count-by-direction
  ticks-to-exit
]
;############## setup ##############

to setup
  ca
  
  set standard-deviation-train-arrival 20
  set time-reserved-for-disembark 0.75     ;between 0 and 1, part of the overall door-opening time that gets reserved for disembarking agents
  set speed-level [1 3 7]
  set speed-level-percentage [0.7 0.95 1]
  set total-stuck-count-by-direction []
  set ticks-to-exit []
  
  ;setup simple station layout
  
  if(layout = "No Obstacle - Normal")[
    import-drawing "no-obst-normal.png"
    import-pcolors "no-obst-normal.png"
    ]
  if(layout = "Single Long Obstacle - Normal")[
    import-drawing "single-long-obst-normal.png"
    import-pcolors "single-long-obst-normal.png"
    ]
  if(layout = "cityhalldouble")[
    import-drawing "cityhalldouble.png"
    import-pcolors "cityhalldouble.png"
    ]
  if(layout = "No Obstacle - Cross")[
    import-drawing "no-obst-cross.png"
    import-pcolors "no-obst-cross.png"
    ]
  if(layout = "No Obstacle - Similar")[
    import-drawing "no-obst-similar.png"
    import-pcolors "no-obst-similar.png"
    ]
  if(layout = "Single Short Obstacle - Normal")[
    import-drawing "single-short-obst-normal.png"
    import-pcolors "single-short-obst-normal.png"
    ]
  if(layout = "Obstacle - Cross")[
    import-drawing "obst-cross.png"
    import-pcolors "obst-cross.png"
    ]
  if(layout = "Double Short Obstacle - Normal")[
    import-drawing "double-short-obst-normal.png"
    import-pcolors "double-short-obst-normal.png"
    ]
  if(layout = "Double Long Obstacle - Normal")[
    import-drawing "double-long-obst-normal.png"
    import-pcolors "double-long-obst-normal.png"
    ]
  if(layout = "1 Exit No Obstacle - Normal")[
    import-drawing "1exit-no-obst-normal.png"
    import-pcolors "1exit-no-obst-normal.png"
    ]
  if(layout = "1 Exit Single Long Obstacle - Normal")[
    import-drawing "1exit-single-long-obst-normal.png"
    import-pcolors "1exit-single-long-obst-normal.png"
    ]
  if(layout = "Close No Obstacle - Normal")[
    import-drawing "close-no-obst-normal.png"
    import-pcolors "close-no-obst-normal.png"
    ]
  if(layout = "Close Single Long Obstacle - Normal")[
    import-drawing "close-single-long-obst-normal.png"
    import-pcolors "close-single-long-obst-normal.png"
    ]
  
  ask patches with [pcolor = 126][
    set plabel "EXIT"
    sprout-exits 1 [set exit-queue [] hide-turtle]
    ;set obstacle true
  ]
  
  ask patches with [(pycor = min-pycor or pycor = max-pycor) and pxcor mod 8 = 0 and (abs (pxcor) - max-pxcor) < -5]
  [
    let doors (patch-set patch-at -1 0 patch-at 1 0 self)
    
    ask doors [
      set pcolor white
      set spawn-point true
      set obstacle true
      ifelse(pycor = max-pycor)[set pdirection 0][set pdirection 1]
    ]
    
    ifelse (pycor = max-pycor)[
      ask patch-at -1  -1 [set pcolor red sprout-train-doors 1 [
          set open? false set t-timer train-arrival-interval / 2  set direction 0 set exit-queue [] hide-turtle]]
      ask patch-at  1  -1 [set pcolor red sprout-train-doors 1 [
          set open? false set t-timer train-arrival-interval / 2  set direction 0 set exit-queue [] hide-turtle]]
    ][
    ask patch-at -1  1 [set pcolor red sprout-train-doors 1 [
        set open? false set t-timer train-arrival-interval set direction 1 set exit-queue [] hide-turtle]]
    ask patch-at  1  1 [set pcolor red sprout-train-doors 1 [
        set open? false set t-timer train-arrival-interval  set direction 1 set exit-queue [] hide-turtle]]
    ]
  ]
  
  ask patches with [pcolor = 12.9][
   set entry-point true
   sprout-entries 1 [hide-turtle
     set tta int random-exponential(1 / lambda-arrival-embark)
   ]
  ] 
  
  ask patches with [ shade-of? pcolor 44.9][
    set obstacle true
  ]
  
  ask patches with [ shade-of? pcolor 64][
    set obstacle true
  ]
  
  ask patches with [ shade-of? pcolor 55][
    set obstacle true
  ]  
  
  reset-ticks
end

;############## main ##############

to go
  update-door-timer
  sprout-new-commuters
  to-color-code
  move
  exit-commuters
  update-reporters
  tick
end

to update-door-timer
  let next-tta int random-normal train-arrival-interval standard-deviation-train-arrival
  foreach n-values 2 [?][
    ask train-doors with [direction = ?][
      if(t-timer = 0)[
        ifelse(open?)[set open? false set pcolor red set t-timer next-tta][set open? true set pcolor green set t-timer door-opening-time set number-of-arrivals lambda-arrival-disembark]
      ]
      set t-timer t-timer - 1
    ]
  ]
end

to sprout-new-commuters
      
  let targets exits 
  
  ;sprout disembarking agents
  foreach n-values 2 [?][
    if(any? train-doors with [direction = ? and open?])[
      
      let remaining-time [t-timer] of one-of train-doors with [direction = ?]
      let next-number-of-arrivals [number-of-arrivals] of one-of train-doors with [direction = ?]
      
      ask patches with [spawn-point = true and pdirection = ?][
        
        ;only during beginning of door opening passengers disembark
        if((remaining-time / door-opening-time ) > time-reserved-for-disembark); 
        
        [
          if(random-float(1) < (next-number-of-arrivals / (time-reserved-for-disembark * door-opening-time)));
          [
            
            sprout-commuters 1 [set born-tick ticks set size 2 set shape "person" set-speed
            let other-train (turtle-set)
            ;interchanging agents
            ifelse(random-float(1) > rate-of-interchange)[
              set exit-path a-star-nlogo:a-star-search self targets
              set direction "exit"
            ]
            [
              set direction "interchange"
                            
              ifelse(? = 1)[
                set other-train train-doors with [direction = 0]
              ]
              [
                set other-train train-doors with [direction = 1]]
                set exit-path a-star-nlogo:a-star-search self other-train
              ]
            set target-door one-of train-doors-on last exit-path
            set enqueued false set exit-path but-first exit-path]
           
          ]
        ]
      ]
    ]
  ]
  
  ;sprout embarking agents
  ask entries[
    ifelse(tta = 0)[    
      let commuter-dir 0
      if(random-float 1 < rate-of-going-towards-direction-1)[set commuter-dir 1]  
      let target one-of train-doors with [direction = commuter-dir]
      set targets (turtle-set target)
      ;if(not any? other turtles-here) [
        ask patch-here [sprout-commuters random-poisson(lambda-arrival-embark) [set born-tick ticks set size 2 set shape "person" set exit-path a-star-nlogo:a-star-search self targets set enqueued false set target-door target set direction "into-train" set exit-path but-first exit-path set-speed]]
      ;]
      set tta int random-exponential(1 / lambda-arrival-embark)
    ]
    [set tta tta - 1]
  ]
 
end

to move
  ask commuters
  [
    if(not enqueued and check-speed-count)
    [
      ifelse(length exit-path > 1)
      [        
        if(direction = "into-train" or direction = "interchange" and not any? train-doors-on first exit-path)
        [
          enqueue-if-queue-found
        ]
        move-next-step
      ]
      [
        if(not empty? exit-path)[
        check-for-exit
        ]         
      ]
    ]
    if(direction = "into-train" or direction ="interchange" and enqueued and [open?] of target-door and length exit-path > 1)[set enqueued false]
  ]        
end

to exit-commuters
  ;disembarking commuters
  ask exits[
    repeat 1 [
      if (not empty? exit-queue)[
        ask first exit-queue[set ticks-to-exit fput (ticks - born-tick) ticks-to-exit die]
        set exit-queue butfirst exit-queue
      ]
    ]
  ]
  
  ;embarking commuters
  foreach n-values 2 [?][
    ask train-doors with [direction = ? and open?][
      if(length exit-queue > 0 and t-timer / door-opening-time < time-reserved-for-disembark)[
        ask first exit-queue [die]
        set exit-queue but-first exit-queue 
      ]
    ]
  ]
end

;############## movement behavior ##############

to move-next-step 
  let targets exits
  if(direction = "into-train" or direction = "interchange")[
    set targets (turtle-set target-door)
  ]

  ifelse(not any? other commuters-on first exit-path)
    [
      set stuck-count 0
      move-to first exit-path
      set exit-path but-first exit-path
    ]
  ;other commuter blocking the way
    [        
      ;random move, if stuck for too long
      if([direction] of one-of other commuters-on first exit-path != [direction] of self)[
        if((abs (max-pycor - [ycor] of self) > 5 and abs ([ycor] of self - min-pycor) > 5))[
          set stuck-count-by-direction stuck-count-by-direction + 1
        ];
      ]
      set stuck-count stuck-count + 1
      if( stuck-count > 5)[
        let tmp one-of neighbors with [not any? commuters-here and not (obstacle != 0)]  
        if (tmp != nobody) [
          move-to tmp
          set stuck-count 0
          avoid-commuter
        ]
         
      ] 
      
    ]
end

to enqueue-if-queue-found
  let nsc commuters-on first exit-path
  set nsc nsc with [direction = "into-train" or direction = "interchange" and enqueued = true]
  if(any? nsc and length exit-path < 5)
    [
      set enqueued true
    ]
end

to check-for-exit
  ;reached the exit, queue for exit and empty exit-path
  ifelse(direction = "into-train" or direction = "interchange")[
    enqueue-for-exit([train-doors-here] of first exit-path)  
  ]
  [
    enqueue-for-exit ([exits-here] of first exit-path)
  ]
end

;avoidance strategy, a certain percentage recalculate the way with taking the blocked step into consideration
to avoid-commuter
  if(random-float(1) < 1)
  [
    let targets exits 
    if(direction = "into-train" or direction = "interchange")[set targets (turtle-set target-door)]

    ;let blocks neighbors with [any? commuters]
    let blocks other commuters with [distance myself < 5]
    if(distance last exit-path < 10)
    [
      let alternative-route a-star-nlogo:a-star-search-with-multiple-turtle-avoidance self targets blocks
      ;avoidance strategy depends on intended direction of agent
      if(direction = "exit"  and not empty? alternative-route)[set exit-path alternative-route]
    ]
    if(direction = "into-train" or direction = "interchange")[
      set exit-path a-star-nlogo:a-star-search-with-turtle-avoidance self targets first exit-path
      ]
    if(empty? exit-path )[show "no way out"]
  ]
end

to set-speed
  ifelse(different-speed)[
    let speed-dist random-float(1)
    
    if(speed-dist < item 0 speed-level-percentage) [set speed item 0 speed-level]
    if(speed-dist > item 0 speed-level-percentage and speed-dist < item 1 speed-level-percentage)[set speed item 1 speed-level]
    if(speed-dist > item 1 speed-level-percentage) [set speed item 2 speed-level]
  ]
  [
    set speed 1
  ]
  set speed-count speed
end

to-report check-speed-count
  let result false
  ifelse(speed-count = 0)[set result true set speed-count speed][set speed-count speed-count - 1]
  report result
end

to enqueue-for-exit [exit-to-queue]  
  ask exit-to-queue[set exit-queue lput myself exit-queue] 
  set enqueued true 
end

;############## observer ##############
to-report time-to-arrival [dir]
  let result 0
  ask one-of train-doors with [direction = dir] [if(t-timer > result)[set result t-timer]]
  report result
end

to to-color-code
  if(color-code = "none")[ask commuters [set color white]]
  if(color-code = "direction")
  [
    ask commuters with [direction = "into-train"][set color white]
    ask commuters with [direction = "interchange"][set color yellow]
    ask commuters with [direction = "exit"][set color blue]
  ]
  if(color-code = "speed")
  [
    ask commuters with [speed = item 0 speed-level][set color 18]
    ask commuters with [speed = item 1 speed-level][set color 16]
    ask commuters with [speed = item 2 speed-level][set color 14] 
  ]
end

to update-reporters
  let result 0
  ask commuters [
    set result result + stuck-count-by-direction
  ] 
  set total-stuck-count-by-direction fput result total-stuck-count-by-direction 
end

to-report mean-stuck-count-by-direction
  let result 0
  if(not empty? total-stuck-count-by-direction)[set result mean total-stuck-count-by-direction]
  report result
end

to-report mean-ticks-to-exit
  let result 0
  if(not empty? ticks-to-exit)[set result mean ticks-to-exit]
  report result
end

to-report actual-stuck-count-by-direction
  let result 0
  if(not empty? total-stuck-count-by-direction)[set result first total-stuck-count-by-direction]
  report result
end
@#$#@#$#@
GRAPHICS-WINDOW
524
53
1479
523
50
23
9.36
1
10
1
1
1
0
0
0
1
-50
50
-23
23
1
1
1
ticks
50.0

BUTTON
18
40
81
73
NIL
setup
NIL
1
T
OBSERVER
NIL
S
NIL
NIL
1

BUTTON
89
39
152
75
NIL
go
NIL
1
T
OBSERVER
NIL
G
NIL
NIL
1

BUTTON
157
41
247
74
go forever
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
400
57
509
102
NIL
time-to-arrival 0
17
1
11

MONITOR
413
475
515
520
NIL
time-to-arrival 1
17
1
11

SLIDER
17
81
189
114
rate-of-interchange
rate-of-interchange
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
196
82
387
115
rate-of-going-towards-direction-1
rate-of-going-towards-direction-1
0
1
0.5
0.05
1
NIL
HORIZONTAL

INPUTBOX
17
121
128
181
train-arrival-interval
600
1
0
Number

INPUTBOX
137
121
242
181
door-opening-time
100
1
0
Number

INPUTBOX
164
188
284
248
lambda-arrival-embark
0.2
1
0
Number

INPUTBOX
19
188
158
248
lambda-arrival-disembark
10
1
0
Number

CHOOSER
739
10
877
55
color-code
color-code
"none" "direction" "speed" "random"
1

CHOOSER
882
10
1129
55
layout
layout
"No Obstacle - Normal" "Single Long Obstacle - Normal" "Single Short Obstacle - Normal" "Double Long Obstacle - Normal" "Double Short Obstacle - Normal" "No Obstacle - Cross" "Obstacle - Cross" "No Obstacle - Similar" "1 Exit No Obstacle - Normal" "1 Exit Single Long Obstacle - Normal" "Close No Obstacle - Normal" "Close Single Long Obstacle - Normal"
0

PLOT
21
260
221
410
stuck by different direction
NIL
NIL
0.0
10.0
0.0
0.1
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot actual-stuck-count-by-direction"

PLOT
22
420
222
570
mean-ticks-to-exit
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot mean-ticks-to-exit"

SWITCH
251
126
393
159
different-speed
different-speed
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270

@#$#@#$#@
NetLogo 5.0.5
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean-stuck-count-by-direction</metric>
    <metric>actual-stuck-count-by-direction</metric>
    <metric>count commuters</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-disembark" first="3" step="3" last="15"/>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-embark" first="0.05" step="0.05" last="0.4"/>
    <enumeratedValueSet variable="layout">
      <value value="&quot;Single Long Obstacle - Normal&quot;"/>
      <value value="&quot;No Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean-stuck-count-by-direction</metric>
    <metric>actual-stuck-count-by-direction</metric>
    <metric>count commuters</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-disembark" first="3" step="3" last="15"/>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-embark">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout">
      <value value="&quot;Single Long Obstacle - Normal&quot;"/>
      <value value="&quot;No Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean total-stuck-count-by-direction</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-disembark">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-embark" first="0.05" step="0.05" last="0.4"/>
    <enumeratedValueSet variable="layout">
      <value value="&quot;Single Long Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment" repetitions="5" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean total-stuck-count-by-direction</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-disembark">
      <value value="15"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-embark" first="0.05" step="0.05" last="0.4"/>
    <enumeratedValueSet variable="layout">
      <value value="&quot;No Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="300"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_single" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean-stuck-count-by-direction</metric>
    <metric>count commuters</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-disembark">
      <value value="10"/>
    </enumeratedValueSet>
    <steppedValueSet variable="lambda-arrival-embark" first="0.05" step="0.05" last="0.3"/>
    <enumeratedValueSet variable="layout">
      <value value="&quot;1 Exit Single Long Obstacle - Normal&quot;"/>
      <value value="&quot;1 Exit No Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="600"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="experiment_2_exits_all_layouts" repetitions="5" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="10000"/>
    <metric>mean-stuck-count-by-direction</metric>
    <metric>mean-ticks-to-exit</metric>
    <enumeratedValueSet variable="rate-of-going-towards-direction-1">
      <value value="0.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-disembark">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda-arrival-embark">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="layout">
      <value value="&quot;No Obstacle - Normal&quot;"/>
      <value value="&quot;Single Long Obstacle - Normal&quot;"/>
      <value value="&quot;Single Short Obstacle - Normal&quot;"/>
      <value value="&quot;Double Long Obstacle - Normal&quot;"/>
      <value value="&quot;Double Short Obstacle - Normal&quot;"/>
      <value value="&quot;No Obstacle - Cross&quot;"/>
      <value value="&quot;Obstacle - Cross&quot;"/>
      <value value="&quot;No Obstacle - Similar&quot;"/>
      <value value="&quot;Close No Obstacle - Normal&quot;"/>
      <value value="&quot;Close Single Long Obstacle - Normal&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="door-opening-time">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="color-code">
      <value value="&quot;direction&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="different-speed">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="train-arrival-interval">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rate-of-interchange">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180

@#$#@#$#@
0
@#$#@#$#@
