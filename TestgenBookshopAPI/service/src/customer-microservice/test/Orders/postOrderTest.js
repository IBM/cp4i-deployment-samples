const request = require('supertest');
const assert = require('chai').assert;
const expect = require('chai').expect;

const app = require('../../app');

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .post('/customers/4a68abb2-8300-4192-8ef0-161db0584397/orders/')
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

describe('POST /customers/{customer_id}/orders/', function () {
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .post('/customers/4a68abb2-8300-4192-8ef0-161db0584397/orders/')
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

describe('POST /customers/{customer_id}/orders/', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 400 if content-type is not json', function (done) {
        request(app)
            .post('/customers/4a68abb2-8300-4192-8ef0-161db0584397/orders/')
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

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the customer_id in the url does not match the request body ', function (done) {
        request(app)
            .post('/customers/6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The customer IDs do not match');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the customer_id is not a valid UUID', function (done) {
        request(app)
            .post('/customers/6bc5c1b/orders/')
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

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 404 if the customer does not exist', function (done) {
        request(app)
            .post('/customers/4a64abb2-8300-4192-8ef0-161db0584397/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '404');
                assert.equal(res.body.message, 'The customer could not be located');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": 'b65331f7-a392-4e79-b4bc-c4b8cf9561b6',
        "book_id": '8-bbc6-97-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the book id is not a valid uuid', function (done) {
        request(app)
            .post('/customers/b65331f7-a392-4e79-b4bc-c4b8cf9561b6/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The book ID is invalid');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '917f68b3-803f-450d-99cb-291ae11c13eb',
        "book_id": '3ac5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 404 if the book does not exist', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '404');
                assert.equal(res.body.message, 'The requested book was not found in the shop');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "book_id": '3aa5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the customer_id field is missing', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'customer_id is a required field');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '917f68b3-803f-450d-99cb-291ae11c13eb',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the book_id field is missing', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'book_id is a required field');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '917f68b3-803f-450d-99cb-291ae11c13eb',
        "book_id": '3aa5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if quantity is missing', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'quantity is a required field');
                done();
            });
    });
});

describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '917f68b3-803f-450d-99cb-291ae11c13eb',
        "book_id": '3aa5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true,
        "someField": "value",
        "random": "ignore this..."
    }
    it('respond with 200 and ignore any additional unwanted fields', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.order, 'object');
                const locationPresent = res.get('Location') === undefined;
                expect(locationPresent).to.be.false;
                assert.notProperty(res.body.order, 'someField');
                assert.notProperty(res.body.order, 'random');
                done();
            });
    });
});

// TODO: Test for 400 error
describe('POST /customers/{customer_id}/orders/', function () {
    let data = {
        "customer_id": '917f68b3-803f-450d-99cb-291ae11c13eb',
        "book_id": '3aa5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 201 if all fields are present and correct', function (done) {
        request(app)
            .post('/customers/917f68b3-803f-450d-99cb-291ae11c13eb/orders/')
            .set('Accept', 'application/json')
            .set('Content-Type', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .send(data)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.order, 'object');
                const locationPresent = res.get('Location') === undefined;
                expect(locationPresent).to.be.false;
                done();
            });
    });
});
