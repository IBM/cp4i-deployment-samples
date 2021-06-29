const authenticate = require('../utils/authenticate')
const delay = require('../utils/delay')
const recordUsage = require('../utils/accounting')
const { checkStringField, checkAdditionalFields } = require('../utils/validate');

async function postCategory(req, res, next) {
    var categories = []
    try {
        authenticate(req, 'admin')
        checkBody(req)
        await delay(500)
        await recordUsage(req, 'category')
        // sometimes we can't determine a category
        const randomNo = Math.floor(Math.random() * 15)
        if (randomNo != 9) {
            categories.push(getCategory(req.body.title))
        }
    }
    catch (err) {
        return next(err)
    }
    res.status(200).json({
        categories
    })
}

function checkBody(req) {
    checkStringField(req, 'title')
    checkStringField(req, 'synopsis', required=false, nonEmpty=false)
    checkAdditionalFields(req, ['title', 'synopsis'])
}

function getCategory(title) {
    const categories = ['biography', 'business', 'computing', 'fiction', 'food', 'history', 'science', 'social']
    const randomIndex = Math.floor(Math.random() * categories.length)
    return categories[randomIndex]
}

module.exports = {
    postCategory
}
