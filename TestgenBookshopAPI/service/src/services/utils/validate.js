const RequestError = require('requesterror')

function checkStringField(req, fieldName, required=true, nonEmpty=true) {
    const body = req.body
    if (!(fieldName in body)) {
        if (required) {
            throw new RequestError(400, 'invalid_input', `The field \'${fieldName}\' is required for this request`, target = {
                type: 'field',
                name: fieldName
            })
        }
        // nothing more to do
        return
    }
    const value = body[fieldName]
    if (typeof value != 'string' || (nonEmpty && !value.trim())) {
        throw new RequestError(400, 'invalid_input', `The field \'${fieldName}\' must be a ${nonEmpty ? 'non-empty string' : 'string'}`, target = {
            type: 'field',
            name: fieldName
        })
    }
}

function checkAdditionalFields(req, fieldNames) {
    const fields = Object.keys(req.body).filter(field => !fieldNames.includes(field))
    if (fields.length > 0) {
        const field = fields[0]
        throw new RequestError(400, 'invalid_input', `The field '${field}' is not allowed in this request`, target = {
            type: 'field',
            name: field
        })
    }
}

module.exports = {
    checkAdditionalFields,
    checkStringField,
}
