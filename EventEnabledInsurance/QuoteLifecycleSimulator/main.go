package main

import (
  "database/sql"
  "fmt"
  "log"
  "math/rand"
  "os"
  "strconv"
  "time"

  "github.com/google/uuid"
  _ "github.com/lib/pq"
)

var host = getEnvString("PG_HOST")
var port = getEnvInt("PG_PORT")
var user = getEnvString("PG_USER")
var password = getEnvString("PG_PASSWORD")
var dbname = getEnvString("PG_DATABASE")
var tickMilliSeconds = getEnvInt("TICK_MILLIS")
var mobileTestRows = getEnvInt("MOBILE_TEST_ROWS")

var nonMobileSources = []string{"Web", "Email", "Letter", "Call Center", "Police"}
// Customer data in order: Name, eMail, Address, USState, LicensePlate
// Names generated using: https://www.name-generator.org.uk/quick/
// Addresses generated using: https://www.randomlists.com/random-addresses
// Licenes plates generated using: https://www.elfqrin.com/uscarlicenseplates.php
var customers = [][]string {
  {"Ronny Doyle", "RonnyDoyle@mail.com", "790 Arrowhead Court, Portsmouth", "VA", "WMC-9628"},
  {"Nella Beard", "NBeard@mail.com", "8774 Inverness Dr., Janesville", "WI", "787-YWR"},
  {"Andy Rosales", "AndyR@mail.com", "9783 Oxford St., Duluth", "GA", "GWL3149"},
}
const minAge = 21
const maxAge = 80
var damageDescriptions = []string{"Cracked windscreen", "Wheel fell off", "Dent in door", "Won't start"}
const newClaimTicks = 3

func main() {
  psqlInfo := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
    host, port, user, password, dbname)
  db, err := sql.Open("postgres", psqlInfo)
  if err != nil {
    panic(err)
  }
  defer db.Close()

  err = db.Ping()
  if err != nil {
    panic(err)
  }
  log.Println("Successfully connected to postgres database")

  count := countQuotes(db);
  if(count<=0) {
    log.Printf("No quotes in table, creating %d new mobile quotes", mobileTestRows)
    for i := 0; i < mobileTestRows; i++ {
      createNewClaim(db, true)
    }
  } else {
    log.Printf("Found %d quotes in table", count)
  }

  ticksToNextNewClaim := newClaimTicks
  for {
    time.Sleep(time.Duration(tickMilliSeconds) * time.Millisecond)
    processMobileClaim(db)
    processNonMobileClaim(db)
    ticksToNextNewClaim--
    if(ticksToNextNewClaim <= 0) {
      createNewClaim(db, false)
      ticksToNextNewClaim = newClaimTicks
    }
  }
}

func processMobileClaim(db *sql.DB) () {
  quoteID, claimStatus := getRandomClaim(db, true)
  if(quoteID == "") {
    log.Printf("No outstanding mobile claims found")
  } else {
    log.Printf("Found mobile claim with quoteID of %s and claimStatus of %d\n", quoteID, claimStatus)
    claimStatus+=1
    updateQuoteStatus(db, quoteID, claimStatus)
  }
}

func processNonMobileClaim(db *sql.DB) () {
  quoteID, claimStatus := getRandomClaim(db, false)
  if(quoteID == "") {
    log.Printf("No outstanding non-mobile claims found")
  } else {
    log.Printf("Found non-mobile claim with quoteID of %s and claimStatus of %d\n", quoteID, claimStatus)
    claimStatus+=1
    // For 2/3 of cases skip 3 and move straight to 4
    if(claimStatus==3 && rand.Intn(3)>0) {
      log.Printf("Skipping claimStatus straight to 4")
      claimStatus=4
    }
    updateQuoteStatus(db, quoteID, claimStatus)
  }
}

func createNewClaim(db *sql.DB, mobile bool) {
  var source string
  if(mobile) {
    source = "Mobile"
  } else {
    source = pickRandomString(nonMobileSources)
  }
  quoteID := uuid.New().String()
  customerInfo := pickRandomStringArray(customers)
  name := customerInfo[0]
  email := customerInfo[1]
  age := minAge+rand.Intn(maxAge-minAge)
  address := customerInfo[2]
  usState := customerInfo[3]
  licensePlate := customerInfo[4]
  descriptionOfDamage := pickRandomString(damageDescriptions)

  sqlStatement := `
    INSERT INTO quotes (
      QuoteID, ClaimStatus, ClaimCost, Source, Name, EMail, Age, Address, USState, LicensePlate, DescriptionOfDamage)
    VALUES ($1, 1, null, $2, $3, $4, $5, $6, $7, $8, $9)
    RETURNING QuoteID AS id`
  id := ""
  err := db.QueryRow(sqlStatement, quoteID, source, name, email, age, address, usState, licensePlate, descriptionOfDamage).Scan(&id)
  if err != nil {
    panic(err)
  }
  log.Printf("Created new claim with id of %s", id)
}

func getRandomClaim(db *sql.DB, mobile bool) (string, int) {
  sqlStatement := `SELECT QuoteID, ClaimStatus FROM quotes WHERE Source`
  if(mobile) {
    sqlStatement += `=`
  } else {
    sqlStatement += `!=`
  }
  sqlStatement += `'Mobile' AND ClaimStatus<7 ORDER BY random() LIMIT 1`
  var quoteID string = ""
  var claimStatus int = -1
  row := db.QueryRow(sqlStatement)
  switch err := row.Scan(&quoteID, &claimStatus); err {
  case sql.ErrNoRows:
  case nil:
    break;
  default:
    panic(err)
  }
  return quoteID, claimStatus
}

func updateQuoteStatus(db *sql.DB, quoteID string, claimStatus int) () {
  var result sql.Result
  var err error
  if(claimStatus==5) {
    claimCost := 100 * rand.Intn(10)
    result, err = db.Exec("UPDATE quotes SET ClaimStatus=$2, ClaimCost=$3 WHERE QuoteID=$1", quoteID, claimStatus, claimCost)
    log.Printf("For claim with quoteID of %s, updating claimStatus to %d and claimCost to %d\n", quoteID, claimStatus, claimCost)
  } else {
    result, err = db.Exec("UPDATE quotes SET ClaimStatus = $2 WHERE QuoteID = $1", quoteID, claimStatus)
    log.Printf("For claim with quoteID of %s, updating claimStatus to %d\n", quoteID, claimStatus)
  }
	if err != nil {
		log.Fatal(err)
	}
	rows, err := result.RowsAffected()
	if err != nil {
		log.Fatal(err)
	}
	if rows != 1 {
		log.Fatalf("expected to affect 1 row, affected %d", rows)
	}
}

func countQuotes(db *sql.DB) (int) {
  sqlStatement := `SELECT COUNT(*) FROM quotes`
  var count int = -1
  row := db.QueryRow(sqlStatement)
  switch err := row.Scan(&count); err {
  case sql.ErrNoRows:
  case nil:
    break;
  default:
    panic(err)
  }
  return count
}

func pickRandomString(choices []string) (string) {
  randomIndex := rand.Intn(len(choices))
  return choices[randomIndex]
}

func pickRandomStringArray(choices [][]string) ([]string) {
  randomIndex := rand.Intn(len(choices))
  return choices[randomIndex]
}

func getEnvString(key string) string {
	val, ok := os.LookupEnv(key)
	if !ok {
		log.Panicf("%s env var not set", key)
	}
	return val
}

func getEnvInt(key string) int {
	str := getEnvString(key)
	val, err := strconv.ParseInt(str, 0, 32)
	if err != nil {
		log.Panicf("Failed to convert '%s' to an int: %v", str, err)
	}
	return int(val)
}
