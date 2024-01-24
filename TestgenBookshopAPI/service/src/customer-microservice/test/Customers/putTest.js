const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');


describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "userTwo",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@outlook.com",
        "password": "password101"
    }
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(403)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '403')
                assert.equal(res.body.message, 'The caller does not have permission to perform the operation')
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    it('respond with 401 if no authorization provided', function (done) {
        let data = {
            "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
            "username": "userTwo",
            "first_name": "User",
            "last_name": "Two",
            "email": "email2@outlook.com",
            "password": "password101"
        }
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .send(data)            
            .set('Accept', 'application/json')
            .expect('Content-Type', /json/)
            .expect(401)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '401');
                assert.equal(res.get('WWW-Authenticate'), 'Access to this resource requires authentication')
                assert.equal(res.body.message, 'The caller could not be authenticated');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 415 if content-type is not json', function (done) {
        request(app)
            .put('/customers/cd46b818-e714-4e55-b978-1b9bb3afdc32')
            .set('Accept', 'application/json')
            .set('Content-Type', 'text/html')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(415)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '415');
                assert.equal(res.body.message, 'Content-Type is missing or is not supported');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "userTwo",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@outlook.com",
        "password": "password101"
    }
    it('respond with 400 if the customer_id is not a valid uuid', function (done) {
        request(app)
            .put('/customers/cd46b818-e1b9bb3afdc32')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The customer ID is invalid');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "james name",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@outlook.com",
        "password": "password101"
    }
    it('respond with 400 if the username is changed', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The username can not be changed');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@.com",
        "password": "password101"
    }
    it('respond with 400 if updated email is invalid', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The updated email is not valid');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@ibm.com",
        "password": "password101"
    }
    it('respond with 400 if the url customer_id does not match the request body', function (done) {
        request(app)
            .put('/customers/cd46b818-e714-4e55-b978-1b9bb3afdc32')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The customer_id can not be changed');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "last_name": "Two",
        "email": "email2@ibm.com",
        "password": "password101"
    }
    it('respond with 400 if request body is missing the first_name field', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'first name is a required field');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "email": "email2@ibm.com",
        "password": "password101"
    }
    it('respond with 400 if request body is missing the last_name field', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'last name is a required field');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "first_name": "User",
        "last_name": "Two",
        "email": "email2@ibm.com",
        "password": "password101"
    }
    it('respond with 400 if request body is missing the username field', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'username is a required field');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "last_name": "Two",
        "password": "password101"
    }
    it('respond with 400 if request body is missing the email field', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'email is a required field');
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "customer_id": '3d75d675-1c61-4bce-8489-e4417ecfaafa',
        "username": "user",
        "first_name": "",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 an empty field is present', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'first name is a required field');
                done();
            });
    });
});

describe('PUT /books', function () {
    let data = {
        "customer_id": '3d75d675-1c61-4bce-8489-e4417ecfaafa',
        "username": "",
        "first_name": "",
        "last_name": "",
        "email": "",
        "password": ""
    }
    it('respond with 400 if multiple empty fields are present', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'username is a required field');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "last_name": "Two",
        "email": "myemail@gmail.com",
        "password": "password101",
        "randomField": "some data",
        "additionalField": "should ignore this..."
    }
    it('respond with 200 if customer details updated and ignore any unrelated fields', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.customer, 'object');
                assert.notProperty(res.body.customer, 'randomField');
                assert.notProperty(res.body.customer, 'additionalField');
                assert.property(res.body.customer, 'username');
                assert.equal(res.body.customer.customer_id, '3d75d675-1c61-4bce-8489-e4417ecfaafa');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}', function () {
    let data = {
        "customer_id": "3d75d675-1c61-4bce-8489-e4417ecfaafa",
        "username": "Username",
        "first_name": "User",
        "last_name": "Two",
        "email": "myemail@gmail.com",
        "password": "password101",
        "phone": "00000000000"
    }
    it('respond with 200 if all required fields are provided and details have been updated', function (done) {
        request(app)
            .put('/customers/3d75d675-1c61-4bce-8489-e4417ecfaafa')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.customer, 'object');
                assert.equal(res.body.customer.customer_id, '3d75d675-1c61-4bce-8489-e4417ecfaafa');
                assert.equal(res.body.customer.phone, '00000000000');
                assert.equal(res.body.customer.username, 'Username');
                done();
            });
    });
});
