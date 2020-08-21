package main

import (
  "database/sql"
  "fmt"
  "time"

  _ "github.com/lib/pq"
  "ibm.com/cp4i/demos/eei/env"
)

var host = env.GetEnvString("PG_HOST")
var port = env.GetEnvInt("PG_PORT")
var user = env.GetEnvString("PG_USER")
var password = env.GetEnvString("PG_PASSWORD")
var dbname = env.GetEnvString("PG_DATABASE")
var tickMilliSeconds = env.GetEnvInt("TICK_MILLIS")

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
  fmt.Println("Successfully connected!")


  for {
    time.Sleep(time.Duration(tickMilliSeconds) * time.Millisecond)
    fmt.Println("Tick!")
    claim := getRandomMobileClaim(db)
    fmt.Printf("claim = %v\n", claim)
  }
}

func getRandomMobileClaim(db *sql.DB) (int) {
  sqlStatement := `SELECT QuoteID FROM quotes ORDER BY random() LIMIT 1`
  var randomid int = -1
  row := db.QueryRow(sqlStatement)
  switch err := row.Scan(&randomid); err {
  case sql.ErrNoRows:
  case nil:
    break;
  default:
    panic(err)
  }
  return randomid
}
