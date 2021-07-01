var express = require('express');

var indexRouter = require('./routes/index');

var app = express();

app.use(express.json());

app.use(function (req, res, next) {
    req.headers['Content-Type'] = req.get('Content-Type') || ("Content-Type", 'application/json');
    next();
});

app.use('/', indexRouter);

const PORT = process.env.BOOK_PORT || 5000;
app.listen(PORT, () => console.log(`App is listening on ${PORT}...`));


module.exports = app;
