const express = require('express')
const RequestError = require('requesterror')
const router = require('./routes/services')

const app = express()

app.use(router)

app.use((req, res, next) => {
    next(new RequestError(404, 'not_found', 'The requested endpoint does not exist on this server'))
})

app.use((err, req, res, next) => {
    console.log(err.message)
    const status = err.status || 500
    if (err instanceof RequestError) {
        json = err.json()
    }
    else {
        const message = (err.expose != false) ? err.message : 'Request failed'
        json = {
            status_code: status,
            errors: [
                {
                    message: message
                }
            ]
        }
    }
    res.set(err.headers || {})
    res.status(status).json(json)
});

const PORT = process.env.SERVICE_PORT || 5000
app.listen(PORT, () => console.log(`App is listening on ${PORT}...`))


module.exports = app
