# RFID station with MCS-51 and EM4095

Source is provided in Assembler.\
EM4095 is RF reader which operates on 125KHz carrier frequency.\
Controller used to control RF reader is AT89S8253.

Tapping of predefiened master card will put the station in registration mode where system user can register or unregister up to 250 cards.

## EEDATA positions
Each card needs 5 bytes of memory to store.\
First 5 bytes are reserved for master card.\
Successive addresses are used for 250 user cards.

