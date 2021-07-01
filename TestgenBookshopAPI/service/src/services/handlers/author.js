const { v4: uuidv4 } = require('uuid')
const authenticate = require('../utils/authenticate')
const delay = require('../utils/delay');
const recordUsage = require('../utils/accounting')
const { checkStringField, checkAdditionalFields } = require('../utils/validate')

async function postAuthor(req, res, next) {
    var authors = []
    try {
        authenticate(req, 'admin')
        checkBody(req)
        await delay(500)
        await recordUsage(req, 'author')
        const name = req.body.author
        // pseudo-check whether an author is known
        if (!name.toLowerCase().startsWith("rob")) {
            authors.push({
                author_name: name,
                author_id: uuidv4()
            })
        }
    }
    catch (err) {
        return next(err)
    }
    res.status(200).json({
        authors
    })
}

function checkBody(req) {
    checkStringField(req, 'author')
    checkAdditionalFields(req, ['author'])
}

module.exports = {
    postAuthor
}
