const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');

describe('GET /customers/{customer_id}/orders/{order_id}/orders/{order_id}', function () {
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .get('/customers/4a6b6752-9f73-40ca-a373-5c19bf026f86/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
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

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 200 if the user is an admin', function (done) {
        request(app)
            .get('/customers/4a6b6752-9f73-40ca-a373-5c19bf026f86/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.order, 'object');
                done();
            });
    });
});

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 400 if the customer_id is not a valid UUID', function (done) {
        request(app)
            .get('/customers/4a2-40ca-a373-5c186/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, 400);
                assert.equal(res.body.message, 'The customer ID is invalid');
                done();
            });
    });
});

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 404 if the order does not exist', function (done) {
        request(app)
            .get('/customers/4aa66752-9f73-40ca-a373-5c19bf026f86/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cd1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, 404);
                assert.equal(res.body.message, 'The requested order does not exist');
                done();
            });
    });
});

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 400 if the order_id is not a valid UUID', function (done) {
        request(app)
            .get('/customers/4aa66752-9f73-40ca-a373-5c19bf026f86/orders/5ede3f73ca1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, 400);
                assert.equal(res.body.message, 'The order number provided is invalid');
                done();
            });
    });
});

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 404 if the customer is not found in the database', function (done) {
        request(app)
            .get('/customers/4ab66752-9f73-40ca-a373-5c19bf026f86/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, 404);
                assert.equal(res.body.message, 'The customer could not be located');
                done();
            });
    });
});

describe('GET /customers/{customer_id}/orders/{order_id}', function () {
    it('respond with 200 if request is ok and check the user_id is correct', function (done) {
        request(app)
            .get('/customers/4a6b6752-9f73-40ca-a373-5c19bf026f86/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.order, 'object');
                done();
            });
    });
});