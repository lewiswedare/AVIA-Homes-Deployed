import Foundation

enum StocklistData {
    static let regions: [StocklistRegion] = [
        brisbane,
        goldCoast,
        sunshineCoast,
        toowoomba
    ]

    // MARK: - Brisbane

    static let brisbane = StocklistRegion(
        name: "BRISBANE",
        subRegions: [northBrisbane, westBrisbane, southBrisbane]
    )

    // MARK: North Brisbane

    static let northBrisbane = StocklistSubRegion(
        name: "North Brisbane",
        estates: [
            aireRiverside,
            atNineteenEstate,
            centralSpringsEstate,
            ridgeviewEstate,
            sageEstate
        ]
    )

    static let aireRiverside = StocklistEstate(
        name: "AIRE RIVERSIDE - CABOOLTURE",
        depositTerms: "$5,000 initial deposit, remaining balance 5% within 3 days of contract signing. Unconditional Contracts Only. Owner Occs only.",
        lots: []
    )

    static let atNineteenEstate = StocklistEstate(
        name: "AT NINETEEN ESTATE - BURPENGARY EAST",
        depositTerms: "$2,000 Initial Deposit\nBalance of 5% Deposit Due 3 Business Days of Contract Execution\nUnconditional Contracts Only",
        lots: [
            StocklistLot(
                lotNumber: "1", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$1,060,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$576,100", packagePrice: "$1,636,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot1",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "2", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$1,045,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$520,400", packagePrice: "$1,565,400", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot2",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "4", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$1,045,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$528,900", packagePrice: "$1,573,900", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot4",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "5", stage: "Stage 1", street: "", landSize: "3009m²", landPrice: "$995,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$538,100", packagePrice: "$1,533,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot5",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "6", stage: "Stage 1", street: "", landSize: "3081m²", landPrice: "$980,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$585,100", packagePrice: "$1,565,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot6",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "7", stage: "Stage 1", street: "", landSize: "3017m²", landPrice: "$955,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$651,400", packagePrice: "$1,606,400", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot7",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "8", stage: "Stage 1", street: "", landSize: "3015m²", landPrice: "$962,500",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$571,900", packagePrice: "$1,534,400", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot8",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "9", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$980,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$543,500", packagePrice: "$1,523,500", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot9",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "11", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$1,010,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$542,600", packagePrice: "$1,552,600", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot11",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "12", stage: "Stage 1", street: "", landSize: "3000m²", landPrice: "$1,025,000",
                registered: "Jun-26", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$536,000", packagePrice: "$1,561,000", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "09.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-AtNineteen-Lot12",
                alternativeDesigns: []
            )
        ]
    )

    static let centralSpringsEstate = StocklistEstate(
        name: "CENTRAL SPRINGS ESTATE - CABOOLTURE",
        depositTerms: "Deposit Terms TBA",
        lots: [
            StocklistLot(
                lotNumber: "76", stage: "Stage 1", street: "", landSize: "450m²", landPrice: "$629,000",
                registered: "Nov-2026", designFacade: "Jarrow Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$436,500", packagePrice: "$1,065,500", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "10.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-CentralSprings-Lot76",
                alternativeDesigns: []
            )
        ]
    )

    static let ridgeviewEstate = StocklistEstate(
        name: "RIDGEVIEW ESTATE - NARANGBA",
        depositTerms: "$1,000 at EOI\nBalance of $10,000 Deposit Payable at Contract Execution\nUnconditional Contracts Only\n5% Build Deposit on Contract Signing",
        lots: [
            StocklistLot(
                lotNumber: "1309", stage: "Stage 13", street: "", landSize: "416m²", landPrice: "$550,000",
                registered: "May-26", designFacade: "Nava South Hampton", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$459,000", packagePrice: "$1,009,000", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "12.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Ridgeview-Lot1309",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "1323", stage: "Stage 13", street: "", landSize: "461m²", landPrice: "$474,000",
                registered: "May-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$620,100", packagePrice: "$1,094,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "15.01.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Ridgeview-Lot1323",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "1324", stage: "Stage 13", street: "", landSize: "397m²", landPrice: "$440,000",
                registered: "May-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$624,900", packagePrice: "$1,064,900", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "15.01.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Ridgeview-Lot1324",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "1326", stage: "Stage 13", street: "", landSize: "443m²", landPrice: "$466,000",
                registered: "May-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$641,100", packagePrice: "$1,107,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "10.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Ridgeview-Lot1326",
                alternativeDesigns: []
            )
        ]
    )

    static let sageEstate = StocklistEstate(
        name: "SAGE ESTATE - BURPENGARY",
        depositTerms: "10% deposit required\nUnconditional Contracts Only",
        lots: [
            StocklistLot(
                lotNumber: "709", stage: "Stage 7", street: "", landSize: "339m²", landPrice: "$529,300",
                registered: "Feb-2027", designFacade: "Solta Yamba", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$428,500", packagePrice: "$954,800", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ Only", availability: "10.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Sage-Lot709",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "736", stage: "Stage 7", street: "", landSize: "336m²", landPrice: "$539,700",
                registered: "Feb-2027", designFacade: "Solta Paddington", buildSize: "160m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$442,200", packagePrice: "$981,900", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ Only", availability: "10.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Sage-Lot736",
                alternativeDesigns: []
            )
        ]
    )

    // MARK: West Brisbane

    static let westBrisbane = StocklistSubRegion(
        name: "West Brisbane",
        estates: [
            amoryEstate,
            forestBrook,
            harrisvillePastures,
            providenceEstate,
            sixMileCreek,
            woodchesterEstate
        ]
    )

    static let amoryEstate = StocklistEstate(
        name: "AMORY ESTATE - RIPLEY",
        depositTerms: "$5,000 Initial Land Deposit - Balance of 5% Upon Contract Signing\nUnconditional Contracts ONLY\n5% Build Deposit Upon Contract Signing",
        lots: [
            StocklistLot(
                lotNumber: "149", stage: "Stage 1B", street: "", landSize: "305m²", landPrice: "$580,000",
                registered: "Apr-26", designFacade: "Solta Yamba", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$421,700", packagePrice: "$1,001,700", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "01.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Amory-Lot149",
                alternativeDesigns: []
            )
        ]
    )

    static let forestBrook = StocklistEstate(
        name: "FOREST BROOK - COLLINGWOOD PARK",
        depositTerms: "$2,000 Initial Deposit - Land Contract must be signed within 5 business days of issue. Remaining 5% Land Deposit upon Contract Execution\n$10,000 Payable Upon EOI Signing. 5% Build Deposit on Contract Signing\nUnconditional Contracts ONLY",
        lots: [
            StocklistLot(
                lotNumber: "27", stage: "Stage 11", street: "", landSize: "554m²", landPrice: "$599,000",
                registered: "Jul-26", designFacade: "Tropea Carolina", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$491,100", packagePrice: "$1,090,100", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot27",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "28", stage: "Stage 11", street: "", landSize: "549m²", landPrice: "$586,000",
                registered: "Jul-26", designFacade: "Tropea Fortitude", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$493,200", packagePrice: "$1,079,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot28",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "29", stage: "Stage 11", street: "", landSize: "1023m²", landPrice: "$739,000",
                registered: "Jul-26", designFacade: "Tropea Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$512,500", packagePrice: "$1,251,500", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot29",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "30", stage: "Stage 11", street: "", landSize: "736m²", landPrice: "$679,000",
                registered: "Jul-26", designFacade: "Tropea Paddington", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$511,100", packagePrice: "$1,190,100", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot30",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "31", stage: "Stage 11", street: "", landSize: "736m²", landPrice: "$679,000",
                registered: "Jul-26", designFacade: "Tropea Paddington", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$511,100", packagePrice: "$1,190,100", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot31",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "174", stage: "Stage 9", street: "", landSize: "758m²", landPrice: "$370,900",
                registered: "Jun-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$711,300", packagePrice: "$1,082,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "24.11.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot174",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "175", stage: "Stage 9", street: "", landSize: "785m²", landPrice: "$379,900",
                registered: "Jun-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$711,300", packagePrice: "$1,091,200", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "24.11.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot175",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "176", stage: "Stage 9", street: "", landSize: "803m²", landPrice: "$385,900",
                registered: "Jun-26", designFacade: "Salina Split Level", buildSize: "217m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$711,300", packagePrice: "$1,097,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "24.11.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-ForestBrook-Lot176",
                alternativeDesigns: []
            )
        ]
    )

    static let harrisvillePastures = StocklistEstate(
        name: "HARRISVILLE PASTURES ESTATE - HARRISVILLE",
        depositTerms: "$5,000 initial holding deposit paid via securexhange at EOI\n5% balance deposit is payable within 7 days of contract execution\nUnconditional Contracts Only.",
        lots: [
            StocklistLot(
                lotNumber: "314", stage: "Stage 3", street: "", landSize: "4319m²", landPrice: "$559,000",
                registered: "May-26", designFacade: "Vieste Carolina", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$445,800", packagePrice: "$1,004,800", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "04.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Harrisville-Lot314",
                alternativeDesigns: [
                    StocklistAlternativeDesign(
                        designFacade: "Porto Yamba", buildSize: "200m²",
                        bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                        buildPrice: "$458,800", packagePrice: "$1,017,800", specification: "Volos"
                    )
                ]
            ),
            StocklistLot(
                lotNumber: "315", stage: "Stage 3", street: "", landSize: "3283m²", landPrice: "$559,000",
                registered: "May-26", designFacade: "Tropea Fortitude", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$451,100", packagePrice: "$1,010,100", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "04.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Harrisville-Lot315",
                alternativeDesigns: [
                    StocklistAlternativeDesign(
                        designFacade: "Porto Paddington", buildSize: "200m²",
                        bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                        buildPrice: "$459,100", packagePrice: "$1,018,100", specification: "Volos"
                    )
                ]
            )
        ]
    )

    static let providenceEstate = StocklistEstate(
        name: "PROVIDENCE ESTATE - SOUTH RIPLEY",
        depositTerms: "Deposit Terms TBA\nUnconditional Contracts Preferred\n5% Build Deposit Upon Contract Signing",
        lots: [
            StocklistLot(
                lotNumber: "548", stage: "Stage 14", street: "", landSize: "310m²", landPrice: "$560,000",
                registered: "Registered", designFacade: "Solta Yamba", buildSize: "160m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$405,200", packagePrice: "$965,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "09.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Providence-Lot548",
                alternativeDesigns: []
            )
        ]
    )

    static let sixMileCreek = StocklistEstate(
        name: "SIX MILE CREEK ESTATE - COLLINGWOOD PARK",
        depositTerms: "$5k Deposit upon Contract Signing\n30 Days for Finance\n14 Day Settlement",
        lots: [
            StocklistLot(
                lotNumber: "264", stage: "Stage 5C", street: "", landSize: "404m²", landPrice: "$459,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "COMING SOON", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "267", stage: "Stage 5C", street: "", landSize: "450m²", landPrice: "$478,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "268", stage: "Stage 5C", street: "", landSize: "515m²", landPrice: "$495,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "305", stage: "Stage 5C", street: "", landSize: "400m²", landPrice: "$459,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "312", stage: "Stage 5C", street: "", landSize: "405m²", landPrice: "$459,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "COMING SOON", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "313", stage: "Stage 5C", street: "", landSize: "450m²", landPrice: "$478,000",
                registered: "Registered", designFacade: "Custom Design", buildSize: "195m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$527,500", packagePrice: "$1,005,500", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "01.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-SixMileCreek-Lot313",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "331", stage: "Stage 5C", street: "", landSize: "405m²", landPrice: "$459,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "336", stage: "Stage 5C", street: "", landSize: "450m²", landPrice: "$478,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "337", stage: "Stage 5C", street: "", landSize: "607m²", landPrice: "$499,000",
                registered: "Registered", designFacade: "COMING SOON", buildSize: "",
                bedrooms: "", bathrooms: "", garages: "", theatre: "",
                buildPrice: "", packagePrice: "", specification: "",
                status: "EOI", ownerOccInvestor: "", availability: "",
                salesPackageLink: nil,
                alternativeDesigns: []
            )
        ]
    )

    static let woodchesterEstate = StocklistEstate(
        name: "WOODCHESTER ESTATE - GATTON",
        depositTerms: "5% Build Deposit on Contract Signing\nUnconditional Contracts ONLY",
        lots: [
            StocklistLot(
                lotNumber: "63", stage: "Stage 4", street: "", landSize: "750m²", landPrice: "$347,000",
                registered: "Oct-2026", designFacade: "Porto South Hampton", buildSize: "200m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$483,600", packagePrice: "$830,600", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "17.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot63",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "69", stage: "Stage 4", street: "", landSize: "751m²", landPrice: "$358,000",
                registered: "Sept-2026", designFacade: "Vieste Fortitude", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$491,200", packagePrice: "$849,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "10.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot69",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "70", stage: "Stage 6", street: "", landSize: "751m²", landPrice: "$358,000",
                registered: "Dec-2026", designFacade: "Tropea Fortitude", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$471,200", packagePrice: "$829,200", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "17.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot70",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "71", stage: "Stage 6", street: "", landSize: "751m²", landPrice: "$358,000",
                registered: "Dec-2026", designFacade: "Tropea South Hampton", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$471,200", packagePrice: "$829,200", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "17.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot71",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "75", stage: "Stage 4", street: "", landSize: "781m²", landPrice: "$367,000",
                registered: "Sept-2026", designFacade: "Tropea Carolina", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$475,900", packagePrice: "$842,900", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "14.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot75",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "80", stage: "Stage 5", street: "", landSize: "750m²", landPrice: "$345,000",
                registered: "Oct-2026", designFacade: "Tropea South Hampton", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "", packagePrice: "", specification: "Volos",
                status: "ON HOLD", ownerOccInvestor: "Owner Occ & Investor", availability: "14.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot80",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "82", stage: "Stage 5", street: "", landSize: "912m²", landPrice: "$365,000",
                registered: "Oct-2026", designFacade: "Jarrow Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "", packagePrice: "", specification: "Volos",
                status: "ON HOLD", ownerOccInvestor: "Owner Occ & Investor", availability: "14.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot82",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "92", stage: "Stage 4", street: "", landSize: "1059m²", landPrice: "$365,000",
                registered: "Sept-26", designFacade: "Nava Fortitude", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$506,400", packagePrice: "$871,400", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "10.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot92",
                alternativeDesigns: [
                    StocklistAlternativeDesign(
                        designFacade: "Tropea Paddington", buildSize: "190m²",
                        bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                        buildPrice: "$511,400", packagePrice: "$876,400", specification: "Volos"
                    )
                ]
            ),
            StocklistLot(
                lotNumber: "93", stage: "Stage 4", street: "", landSize: "1591m²", landPrice: "$397,500",
                registered: "Sept-26", designFacade: "Nava Fortitude", buildSize: "180m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "", packagePrice: "", specification: "Volos",
                status: "ON HOLD", ownerOccInvestor: "Owner Occ & Investor", availability: "10.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot93",
                alternativeDesigns: [
                    StocklistAlternativeDesign(
                        designFacade: "Tropea Paddington", buildSize: "190m²",
                        bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                        buildPrice: "", packagePrice: "", specification: "Volos"
                    ),
                    StocklistAlternativeDesign(
                        designFacade: "Bonney Dual", buildSize: "220m²",
                        bedrooms: "5", bathrooms: "3", garages: "2", theatre: "0",
                        buildPrice: "", packagePrice: "", specification: "Volos"
                    )
                ]
            ),
            StocklistLot(
                lotNumber: "95", stage: "Stage 5", street: "", landSize: "1066m²", landPrice: "$385,000",
                registered: "Oct-2026", designFacade: "Tropea Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "", packagePrice: "", specification: "Volos",
                status: "ON HOLD", ownerOccInvestor: "Owner Occ & Investor", availability: "14.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Woodchester-Lot95",
                alternativeDesigns: []
            )
        ]
    )

    // MARK: South Brisbane

    static let southBrisbane = StocklistSubRegion(
        name: "South Brisbane",
        estates: [
            altoEstate,
            flourishEstate
        ]
    )

    static let altoEstate = StocklistEstate(
        name: "ALTO ESTATE - PARK RIDGE",
        depositTerms: "$5,000 Initial Deposit\n5% Balance of Deposit on Land Contract Signing\nUnconditional Contract - no finance term offered\nOwner Occ Only\nSettlement 14 Days After Title Registration",
        lots: []
    )

    static let flourishEstate = StocklistEstate(
        name: "FLOURISH ESTATE - SOUTH MACLEAN",
        depositTerms: "$5,000 Initial Deposit\n10% Balance of Deposit on Land Contract Signing\n5% Build Deposit at Build Contract Signing\nOwner Occ Only",
        lots: [
            StocklistLot(
                lotNumber: "127", stage: "Stage 1", street: "", landSize: "375m²", landPrice: "$556,250",
                registered: "Dec-2026", designFacade: "Tropea Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$441,400", packagePrice: "$997,650", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ ONLY", availability: "10.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Flourish-Lot127",
                alternativeDesigns: []
            )
        ]
    )

    // MARK: - Gold Coast

    static let goldCoast = StocklistRegion(
        name: "GOLD COAST",
        subRegions: [
            StocklistSubRegion(
                name: "Gold Coast",
                estates: [oaklandEstate, oakviewHeights]
            )
        ]
    )

    static let oaklandEstate = StocklistEstate(
        name: "OAKLAND ESTATE - BEAUDESERT",
        depositTerms: "$1,000 Initial Deposit at EOI\n5% Balance of Deposit on Land Contract Signing\n5% Build Deposit at Build Contract Signing",
        lots: [
            StocklistLot(
                lotNumber: "1", stage: "Stage 2", street: "", landSize: "525m²", landPrice: "$345,000",
                registered: "3rd Q 2026", designFacade: "Custom Design", buildSize: "200m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "0",
                buildPrice: "$550,100", packagePrice: "$895,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner OCC & Investor", availability: "17.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Oakland-Lot1",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "6", stage: "Stage 2", street: "", landSize: "910m²", landPrice: "$385,000",
                registered: "3rd Q 2026", designFacade: "Madrid Fortitude", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$581,900", packagePrice: "$966,900", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner OCC & Investor", availability: "23.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Oakland-Lot6",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "9", stage: "Stage 2", street: "", landSize: "499m²", landPrice: "$322,500",
                registered: "August-2026", designFacade: "Custom Design", buildSize: "210m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$559,200", packagePrice: "$881,700", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner OCC & Investor", availability: "30.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Oakland-Lot9",
                alternativeDesigns: []
            )
        ]
    )

    static let oakviewHeights = StocklistEstate(
        name: "OAKVIEW HEIGHTS - BEAUDESERT",
        depositTerms: "Deposit Terms TBA",
        lots: [
            StocklistLot(
                lotNumber: "212", stage: "", street: "", landSize: "801m²", landPrice: "$475,000",
                registered: "January-2027", designFacade: "Tropea Carolina", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$489,200", packagePrice: "$964,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner OCC & Investor", availability: "14.04.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-OakviewHeights-Lot212",
                alternativeDesigns: []
            )
        ]
    )

    // MARK: - Sunshine Coast

    static let sunshineCoast = StocklistRegion(
        name: "SUNSHINE COAST",
        subRegions: [
            StocklistSubRegion(
                name: "Sunshine Coast",
                estates: []
            )
        ]
    )

    // MARK: - Toowoomba

    static let toowoomba = StocklistRegion(
        name: "TOOWOOMBA",
        subRegions: [
            StocklistSubRegion(
                name: "Toowoomba",
                estates: [
                    gainsboroughLodge,
                    habitatEstate,
                    theHillsCollection,
                    walermareEstate
                ]
            )
        ]
    )

    static let gainsboroughLodge = StocklistEstate(
        name: "GAINSBOROUGH LODGE - GLENVALE",
        depositTerms: "Land: $5,000 at EOI\nFurther $5,000 at Contract Signing\nBuild: Balance of 5% Build Deposit at Contract Signing\nUnconditional Contracts Only",
        lots: []
    )

    static let habitatEstate = StocklistEstate(
        name: "HABITAT ESTATE - MOUNT KYNOCH",
        depositTerms: "Deposit terms TBC",
        lots: [
            StocklistLot(
                lotNumber: "118", stage: "Vast Precinct", street: "", landSize: "500m²", landPrice: "$425,000",
                registered: "Jun-26", designFacade: "Porto Fortitude", buildSize: "200m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$494,000", packagePrice: "$919,000", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner Occ & Investor", availability: "24.11.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Habitat-Lot118",
                alternativeDesigns: []
            )
        ]
    )

    static let theHillsCollection = StocklistEstate(
        name: "THE HILLS COLLECTION - GLENVALE",
        depositTerms: "Unconditional Contracts Only\n5% Deposit Payable within 3 Business Days of Contract Execution\nOwner Occ and Investor Allowed",
        lots: [
            StocklistLot(
                lotNumber: "19", stage: "Stage 3", street: "", landSize: "441m²", landPrice: "$399,000",
                registered: "May-2026", designFacade: "Tropea Fortitude", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$510,800", packagePrice: "$909,800", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner OCC & Investor", availability: "31.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-HillsCollection-Lot19",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "22", stage: "Stage 3", street: "", landSize: "416m²", landPrice: "$389,000",
                registered: "May-2026", designFacade: "Jarrow Ascot", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$509,200", packagePrice: "$898,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner OCC & Investor", availability: "31.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-HillsCollection-Lot22",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "23", stage: "Stage 3", street: "", landSize: "416m²", landPrice: "$389,000",
                registered: "May-2026", designFacade: "Tropea Yamba", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$507,100", packagePrice: "$896,100", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner OCC & Investor", availability: "31.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-HillsCollection-Lot23",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "24", stage: "Stage 3", street: "", landSize: "416m²", landPrice: "$389,000",
                registered: "May-2026", designFacade: "Jarrow Paddington", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$500,300", packagePrice: "$889,300", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner OCC & Investor", availability: "31.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-HillsCollection-Lot24",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "26", stage: "Stage 3", street: "", landSize: "410m²", landPrice: "$387,000",
                registered: "May-2026", designFacade: "Jarrow South Hampton", buildSize: "190m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$500,100", packagePrice: "$887,100", specification: "Volos",
                status: "EOI", ownerOccInvestor: "Owner OCC & Investor", availability: "31.03.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-HillsCollection-Lot26",
                alternativeDesigns: []
            )
        ]
    )

    static let walermareEstate = StocklistEstate(
        name: "WALERMARE ESTATE - TOOWOOMBA",
        depositTerms: "$5,000.00 (Initial Deposit/EOI Fee) Payable Upon Signing of EOI\nBalance of 5% payable within 3 business days from Date of Contract.\nUnconditional Contracts Preferred\nFinance Terms Available Upon Request",
        lots: [
            StocklistLot(
                lotNumber: "28", stage: "Stage 1", street: "", landSize: "2295m²", landPrice: "$559,500",
                registered: "Mar-26", designFacade: "Oristano", buildSize: "284m²",
                bedrooms: "5", bathrooms: "2.5", garages: "2", theatre: "1",
                buildPrice: "$719,025", packagePrice: "$1,278,525", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "01.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Walermare-Lot28",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "29", stage: "Stage 1", street: "", landSize: "2295m²", landPrice: "$559,500",
                registered: "Mar-26", designFacade: "Oristano", buildSize: "284m²",
                bedrooms: "5", bathrooms: "2.5", garages: "2", theatre: "1",
                buildPrice: "$713,700", packagePrice: "$1,273,200", specification: "Volos",
                status: "Available", ownerOccInvestor: "Owner Occ & Investor", availability: "01.12.2025",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Walermare-Lot29",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "53", stage: "Stage 2", street: "", landSize: "2250m²", landPrice: "$589,500",
                registered: "June-2027", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$653,400", packagePrice: "$1,242,900", specification: "Volos",
                status: "Available (Exclusive)", ownerOccInvestor: "Owner OCC & Investor", availability: "23.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Walermare-Lot53",
                alternativeDesigns: []
            ),
            StocklistLot(
                lotNumber: "65", stage: "Stage 2", street: "", landSize: "2255m²", landPrice: "$619,500",
                registered: "June-2027", designFacade: "Talinn", buildSize: "270m²",
                bedrooms: "4", bathrooms: "2", garages: "2", theatre: "1",
                buildPrice: "$629,500", packagePrice: "$1,249,000", specification: "Volos",
                status: "Available (Exclusive)", ownerOccInvestor: "Owner OCC & Investor", availability: "23.02.2026",
                salesPackageLink: "https://drive.google.com/drive/folders/1-Walermare-Lot65",
                alternativeDesigns: []
            )
        ]
    )
}
