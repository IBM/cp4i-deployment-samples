const request = require('supertest');
const assert = require('chai').assert;
const expect = require('chai').expect;
 
const app = require('../../app');

describe('POST /customers', function () {
    let data = {
        "username": "UserOne",
        "first_name": "User",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .send(data)
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

describe('POST /customers', function () {
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .post('/customers')
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

describe('POST /customers', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 400 if content-type is not json', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'text/html')
            .set('Content-Type', 'text/html')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect(415)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '415');
                assert.equal(res.body.message, 'Content-Type is missing or is not supported');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "UserOne",
        "first_name": "User",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 200 if the user is an admin', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(403)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '403');
                assert.equal(res.body.message, 'The caller does not have permission to perform the operation');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "first_name": "User",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 if the username field is missing', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "user",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 if the first_name field is missing', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "user",
        "first_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 if the last_name field is missing', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "user",
        "first_name": "User",
        "last_name": "One",
        "password": "password101"
    }
    it('respond with 400 if the email field is missing', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "user",
        "first_name": "Name",
        "last_name": "One",
        "email": "email@gmail.com",
    }
    it('respond with 400 if the password field is missing', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'password is a required field');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "robUser",
        "first_name": "rob",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 if the username is already in use', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The requested username is in use already');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "robUser",
        "first_name": "rob",
        "last_name": "One",
        "email": "email",
        "password": "password101"
    }
    it('respond with 400 if the email provided is not valid', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The email provided is not valid');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "testUser",
        "first_name": "User",
        "last_name": "One",
        "email": "email@ibm.com",
        "password": "pass"
    }
    it('respond with 400 if the password provided does not meet the requirements', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'A password must have a length of at least 7 and contain at least 1 number');
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "user",
        "first_name": "",
        "last_name": "One",
        "email": "email@gmail.com",
        "password": "password101"
    }
    it('respond with 400 empty fields are present', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "",
        "first_name": "",
        "last_name": "",
        "email": "",
        "password": ""
    }
    it('respond with 400 if multiple empty fields are present', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
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

describe('POST /customers', function () {
    let data = {
        "username": "testUser",
        "first_name": "UserName",
        "last_name": "One",
        "email": "email@ibm.com",
        "password": "password101",
        "extraField": "ignore this",
        "moreFields": "should be ignored"
    }
    it('respond with 201 and ignore any additional fields when creating the user', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.notProperty(res.body.customer, 'extraField');
                assert.notProperty(res.body.customer, 'moreFields');
                assert.typeOf(res.body.customer, 'object');
                const locationPresent = res.get('Location') === undefined;
                expect(locationPresent).to.be.false;
                done();
            });
    });
});

describe('POST /customers', function () {
    let data = {
        "username": "testUser",
        "first_name": "UserName",
        "last_name": "One",
        "email": "email@ibm.com",
        "password": "password101"
    }
    it('respond with 201 if all fields are present and valid', function (done) {
        request(app)
            .post('/customers')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.customer, 'object');
                const locationPresent = res.get('Location') === undefined;
                expect(locationPresent).to.be.false;
                done();
            });
    });
});
