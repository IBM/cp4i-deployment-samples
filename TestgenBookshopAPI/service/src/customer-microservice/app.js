const express = require('express');
const indexRouter = require('./routes/index');

const app = express();

app.use(express.json());

app.use(function (req, res, next) {
    req.headers['Content-Type'] = req.get('Content-Type') || ("Content-Type", 'application/json');
    next();
});

app.use('/', indexRouter);

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => console.log(`App is listening on ${PORT}...`));


module.exports = app;
