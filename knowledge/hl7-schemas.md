# HL7 v2 Message Schemas Reference for AI Agents

## 1. Common Message Types in Site TIE

### ADT (Admit/Discharge/Transfer)
| Event | Name | Trigger |
|-------|------|---------|
| A01 | Admit/Visit Notification | Patient admitted |
| A02 | Transfer | Patient transferred |
| A03 | Discharge | Patient discharged |
| A04 | Register Patient | Outpatient registration |
| A05 | Pre-admit | Pre-admission |
| A08 | Update Patient Information | Demographics update |
| A11 | Cancel Admit | Cancel admission |
| A12 | Cancel Transfer | Cancel transfer |
| A13 | Cancel Discharge | Cancel discharge |
| A28 | Add Person Information | New person record |
| A31 | Update Person Information | Update person record |
| A34 | Merge Patient ID | Merge two patient IDs |
| A40 | Merge Patient Account | Merge accounts |

**ADT_A01 Structure:**
```
MSH  Message Header
EVN  Event Type
PID  Patient Identification
PV1  Patient Visit
[PV2] Patient Visit Additional
[{NK1}] Next of Kin
[{DG1}] Diagnosis
[{AL1}] Allergy
```

### ORM (Order)
| Event | Name |
|-------|------|
| O01 | General Order |

**ORM_O01 Structure:**
```
MSH
PID
PV1
{ORC  Order Common
 OBR  Observation Request
 [{NTE}] Notes
 [{OBX}] Observations}
```

### ORU (Result)
| Event | Name |
|-------|------|
| R01 | Unsolicited Observation Result |

**ORU_R01 Structure:**
```
MSH
PID
PV1
{ORC
 OBR  Observation Request
 [{OBX  Observation/Result
   [{NTE}]}]}
```

### RDE (Pharmacy Order)
| Event | Name |
|-------|------|
| O11 | Pharmacy/Treatment Encoded Order |

**RDE_O11 Structure:**
```
MSH
PID
PV1
{ORC
 RXE  Pharmacy/Treatment Encoded Order
 [{RXR}] Pharmacy Route
 [{RXC}] Pharmacy Component}
```

### SIU (Scheduling)
| Event | Name |
|-------|------|
| S12 | Notification of new appointment booking |
| S13 | Notification of appointment rescheduling |
| S14 | Notification of appointment modification |
| S15 | Notification of appointment cancellation |

### MDM (Medical Document)
| Event | Name |
|-------|------|
| T02 | Original document notification and content |

**MDM_T02 Structure:**
```
MSH
EVN
PID
PV1
TXA  Transcription Document Header
{OBX} Observation (document content)
```

## 2. Key Segments and Fields

### MSH (Message Header)
| Field | ID | Description |
|-------|-----|-------------|
| Sending Application | MSH:3 | e.g., "CERNER", "IPM" |
| Sending Facility | MSH:4 | e.g., "BRI" |
| Receiving Application | MSH:5 | |
| Message DateTime | MSH:7 | TS format |
| Message Type | MSH:9.1 | e.g., "ADT" |
| Trigger Event | MSH:9.2 | e.g., "A01" |
| Message Control ID | MSH:10 | Unique ID |
| Version ID | MSH:12 | e.g., "2.4" |

### PID (Patient Identification)
| Field | ID | Description |
|-------|-----|-------------|
| Patient ID (MRN) | PID:3(1).1 | BTHFT MRN in Site |
| Patient Name - Family | PID:5.1 | Last name |
| Patient Name - Given | PID:5.2 | First name |
| Date of Birth | PID:7 | TS format |
| Sex | PID:8 | M/F/U |
| Address | PID:11 | XAD type |
| Phone | PID:13 | |
| NHS Number | PID:3(2).1 | Often in repeat 2 |
| Death Indicator | PID:30 | Y/N |
| Death DateTime | PID:29 | TS format |

### PV1 (Patient Visit)
| Field | ID | Description |
|-------|-----|-------------|
| Patient Class | PV1:2 | I=Inpatient, O=Outpatient, E=Emergency |
| Assigned Location | PV1:3 | Ward/Bed |
| Attending Doctor | PV1:7 | XCN type |
| Visit Number | PV1:19 | |
| Admit DateTime | PV1:44 | |
| Discharge DateTime | PV1:45 | |

### OBR (Observation Request)
| Field | ID | Description |
|-------|-----|-------------|
| Placer Order Number | OBR:2 | |
| Filler Order Number | OBR:3 | |
| Universal Service ID | OBR:4 | Test/procedure code |
| Observation DateTime | OBR:7 | |
| Results Status | OBR:25 | F=Final, P=Preliminary |

### OBX (Observation)
| Field | ID | Description |
|-------|-----|-------------|
| Value Type | OBX:2 | NM=Numeric, ST=String, TX=Text |
| Observation Identifier | OBX:3 | Test code |
| Observation Value | OBX:5 | The result value |
| Units | OBX:6 | |
| Reference Range | OBX:7 | |
| Abnormal Flags | OBX:8 | H=High, L=Low, A=Abnormal |

### RXE (Pharmacy Encoded Order)
| Field | ID | Description |
|-------|-----|-------------|
| Give Code | RXE:2 | Drug code (RXE:2.1=ID, RXE:2.2=Name) |
| Give Amount - Minimum | RXE:3 | Ordered dose |
| Give Units | RXE:4 | Dose units |
| Give Dosage Form | RXE:5 | |
| Give Rate Amount | RXE:22 | |

## 3. HL7 Path Syntax in IRIS

```
Segment:Field.Component.SubComponent
Segment:Field(Repeat).Component

Examples:
  MSH:9.1          â†’ Message type (e.g., "ADT")
  MSH:9.2          â†’ Trigger event (e.g., "A01")
  PID:3(1).1       â†’ First patient ID, first component (MRN)
  PID:3(2).1       â†’ Second patient ID (often NHS Number)
  PID:5.1          â†’ Family name
  PID:5.2          â†’ Given name
  OBX:5            â†’ Observation value
  OBR:4.1          â†’ Universal service ID code
  RXE:2.1          â†’ Drug code identifier
  RXE:2.2          â†’ Drug name
  RXE:3            â†’ Give amount (dose)
```

## 4. Document Types (DocType)

In IRIS, HL7 messages have a DocType specifying the schema and structure:
```
Schema:MessageStructure
Examples:
  2.3:ADT_A01
  2.4:ADT_A01
  2.3.1:ORM_O01
  2.4:ORU_R01
  CERNER2.3:ADT_A04    (custom Cerner schema)
  2.3:RDE_O11
  2.4:MDM_T02
  2.4:SIU_S12
```

## 5. HL7 Acknowledgments (ACK)

```
MSH|^~\&|RECEIVING|FAC|SENDING|FAC|20260217120000||ACK|CTRL123|P|2.4
MSA|AA|ORIGINAL_CTRL_ID

MSA-1 Acknowledgment Code:
  AA = Application Accept
  AE = Application Error
  AR = Application Reject
```

