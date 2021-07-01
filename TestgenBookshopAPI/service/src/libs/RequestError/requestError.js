module.exports =  class RequestError extends Error {
    constructor(code, reason, message, target, headers) {
        super(message)
        this.code = code
        this.reason = reason
        this.target = target
        this.headers = headers
        // for general compatibility
        this.status = this.statusCode = code
    }

    json() {
        const error = {
            code: this.reason,
            message: this.message,
        }
        if (this.target) {
            error.target = this.target
        }
        return {
            status_code: this.code,
            errors: [
                error
            ]
        }
    }
}
