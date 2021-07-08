const fs = require('fs');
const path = require('path');

var dbFilePath = path.join(__dirname, '..', 'client', 'python', 'books.db');

var authors = ["Ben", "John", "Campbell", "Ricky", "Lucifer", "David", "Ron", "Ronan", "Kevin", "Ashley", "Lara", "Rob", "Mitchell", "Allan", "Dillon", "Kurt", "Rohit", "Rosie", "Lucy", "Tom", "Nancy", "Parker", "Penny"];

var publishers = ["Deployment", "Samples", "Repository", "AI Testgen", "Bookshop Client", "Bookshop Services", "DDD", "EEI", "CCR", "WCB"];

var titles = ["fan", "books", "process", "math", "case", "publish", "test", "testgen", "shop", "grocery", "random", "length", "date", "month", "day", "weekday", "weekend", "year", "full", "empty", "half", "data", "end", "start", "mid", "middle", "top", "bottom", "shelf", "tray", "run", "sit", "stand", "file", "itself", "mayday", "flight", "monitor", "laptop", "bike", "sun", "rainy", "snow", "autumn", "winter", "windy", "candy", "solution", "issue", "board", "tab", "tablet", "base", "wire", "hub", "socket", "key", "lock", "mug", "camera"];

for (var i = 0; i < 5000; i++) {
  var randomDate = genRandomDate(new Date(1990, 0, 1), new Date());
  obj = {
    "title": titles[Math.floor(Math.random() * titles.length)] + " " + titles[Math.floor(Math.random() * titles.length)],
    "author": authors[Math.floor(Math.random() * authors.length)],
    "publisher": publishers[Math.floor(Math.random() * publishers.length)],
    "date": randomDate.getFullYear() + '-' + ('0' + (randomDate.getMonth() + 1)).slice(-2) + '-' + ('0' + randomDate.getDate()).slice(-2)
  }
  fs.appendFile(dbFilePath, JSON.stringify(obj) + '\n', function (err) {
    if (err) throw err;
  });
}

function genRandomDate(start, end) {
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()));
}

// run using:
// node create - client - db.js