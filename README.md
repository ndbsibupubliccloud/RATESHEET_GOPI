# Rate Sheet Modernization POC (`ratesheet-poc`)

Enterprise proof-of-concept migrating legacy SAP ECC transaction `ZR01` (monolithic 4,038-line report `ZSYMP_PR_DETAILS_NEW` and flat table `ZPR_ALV_UPDATE`) to **SAP Cloud-Ready Clean-Core architecture** using the **ABAP RESTful Application Programming Model (RAP)** and **SAP Fiori Elements V4**.

---

## 🏛 Architecture Overview

The solution replaces the legacy flat-file transaction with a structured 4-level composition business object with transactional draft support, strict authorization checks, automated BOM explosion, dynamic vendor fan-out, multi-level costing roll-ups, and 4-tier GST calculations.

```
                           +--------------------------------------+
                           |   SAP Fiori Elements V4 LROP UI      |
                           |   (List Report + Object Page)        |
                           +-------------------+------------------+
                                               |
                                        OData V4 Service
                                       (ZUI_RSH_HEADER_O4)
                                               |
+----------------------------------------------v-----------------------------------------------+
| SAP RAP Business Object (Package Z_RATESHEET / Service ZSD_RSH_HEADER)                       |
|                                                                                              |
|  [Root] RateSheetHeader (ZI_RSH_HEADER / ZC_RSH_HEADER)                                      |
|    │  - Draft master, Lock master, Total ETag, Instance Authorization                        |
|    │  - Mandatory PR, Item, Plant input dialog; Auto-derivation & BOM explosion              |
|    │  - Actions: Recreate, Check BOM, Acknowledge Drift, Copy Reference, Create Contract     |
|    │                                                                                         |
|    └── [Level 1] RateSheetItem (ZI_RSH_ITEM / ZC_RSH_ITEM)                                   |
|         │  - Main Grid with plant-specific vendor fan-out & condition pricing (ZP00 / ZE*)   |
|         │  - 4-component GST (IGST/CGST/SGST/UGST), Modvat, Net landed & Total value         |
|         │                                                                                    |
|         └── [Level 2] KitCostingItem (ZI_RSH_KIT / ZC_RSH_KIT)                               |
|              │  - Kit-level costing & secondary BOM explosion (PCWTGMS, PCWTGROSS, ZE31, ZE32) |
|              │  - Roll-up from Level-3 Raw Materials to Level-2 Kit                          |
|              │                                                                               |
|              └── [Level 3] RawMaterialCostingItem (ZI_RSH_RAW / ZC_RSH_RAW)                  |
|                   - Component raw materials, Freight, Handling, Coloring, Net Cost           |
|                   - Multi-vendor pricing selection and bottom-up roll-up                      |
+----------------------------------------------------------------------------------------------+
```

---

## 📂 Repository Structure

```
ratesheet-poc/
├── .abapgit.xml                  # abapGit repo descriptor (STARTING_FOLDER=/abap/src/, PREFIX)
├── abap/                         # SAP ABAP RAP Backend, package Z_RATESHEET (abapGit format)
│   ├── README.md                 # ABAP layer documentation + import steps
│   └── src/                      # flat: package.devc.xml + <obj>.<type>.xml + source per object
│
├── frontend/                     # SAP Fiori Elements V4 Application
│   ├── webapp/
│   │   ├── annotations/          # Local annotations (SideEffects, UI labels)
│   │   ├── i18n/                 # Translatable text bundles
│   │   ├── localService/         # OData V4 service metadata (metadata.xml)
│   │   ├── Component.js
│   │   ├── index.html
│   │   └── manifest.json         # 4-level routing hierarchy & table configurations
│   ├── package.json              # UI5 build scripts and dependencies
│   ├── ui5.yaml                  # UI5 tooling server configuration
│   └── ui5-local.yaml            # Local development UI5 configuration
│
├── docs/                         # Technical Specifications, Assessments & Reports
│   ├── Clean-Core-Assessment-RateSheet.md            # Clean Core A-D classification
│   ├── Plan-Review-RateSheet.md                      # Architecture and plan review
│   ├── RAP-Implementation-Plan-RateSheet.md          # Detailed engineering specification
│   ├── RAP-Implementation-Report-RateSheet.md        # RAP skeleton implementation report
│   ├── RateSheet-Implementation-And-Testing-Guide.md # End-to-end testing & validation guide
│   ├── SAP-Migration-Completeness-Review-RateSheet.md# Parity review vs legacy ZR01
│   ├── system-info.md                                # SAP system landscape metadata
│   └── specs/                                        # Legacy documentation & sample datasets
│       ├── Rate Sheet sample data with technical column.XLSX
│       ├── Ratesheet Application--Business objective.docx
│       ├── ZMM_R_RATESHEET_Legacy System Code.docx
│       ├── ZPR_ALV_UPDATE_Legacy Table to store the ratesheet data.xlsx
│       └── ZR01 Screnshots.xlsx
│
├── knowledge-base/               # Living Project Memory & Audit Trail
│   ├── 01-progress-log.md        # Complete audit of all actions and implementations
│   ├── 02-manual-activities.md   # Non-tooling steps (Basis, transport, auth)
│   ├── 03-assumptions.md         # Documented design & business assumptions
│   ├── 04-design-and-schema.md   # As-built data model, field mapping & tables
│   ├── 05-open-clarifications.md # Functional & business open questions
│   └── README.md
│
├── .gitignore
└── README.md                     # This file
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js (v18 or higher)
- npm (v9 or higher)
- Access to SAP System with package `Z_RATESHEET` deployed (or mock service)

### Running the Frontend Locally

1. Navigate to the frontend directory:
   ```sh
   cd frontend
   ```

2. Install dependencies:
   ```sh
   npm install
   ```

3. Build the application:
   ```sh
   npm run build
   ```

4. Launch the application locally against the SAP backend:
   ```sh
   npm start
   ```

---

## 🧪 Testing & Validation

### 1. ABAP Unit Tests
The backend behavior pool includes automated unit test suites (`ltc_ratesheet_unit_tests` in `abap/src/zbp_i_rsh_header.clas.testclasses.abap`):
- `test_kit_costing_formulas`: Validates PCWTGROSS, RCOSTPERPC, MCOSTPERPC, PRODUCTCOSTPERPC.
- `test_raw_material_formulas`: Validates IGST, total cost, net landed, basic material, and net cost calculations.
- `test_kit_rollup_formulas`: Validates Level-2 Kit to Level-1 Item price roll-up and average rate calculations.
- `test_rsno_format`: Validates 13-digit legacy Rate Sheet Number formatting (`PR + Item`).

### 2. End-to-End Verification
Refer to [RateSheet-Implementation-And-Testing-Guide.md](docs/RateSheet-Implementation-And-Testing-Guide.md) for detailed test cases, mock data profiles, and step-by-step user journey validation.

---

## 📊 Clean Core Compliance

- **RAP Strict(2)** managed implementation.
- All database accesses use **CDS View Entities** (`PROVIDER CONTRACT TRANSACTIONAL_QUERY`).
- Zero direct `SELECT` statements on unreleased tables `KONP` / `A017`.
- Master data queries routed through SAP-released C1 APIs:
  - `I_PurchaseRequisitionItemAPI01`
  - `I_PurchasingInfoRecordAPI01`
  - `I_PurgInfoRecdOrgPlntDataAPI01`
  - `I_Supplier`, `I_Plant`, `I_ProductDescription`
