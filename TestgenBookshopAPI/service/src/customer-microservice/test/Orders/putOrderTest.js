const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');


describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .send(data)
            .set('Accept', 'application/json')
            .expect('Content-Type', /json/)
            .expect(401)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '401');
                assert.equal(res.get('WWW-Authenticate'), 'Access to this resource requires authentication');
                assert.equal(res.body.message, 'The caller could not be authenticated');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 415 if content-type is not json', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .set('Accept', 'application/json')
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the customer_id is not a valid uuid', function (done) {
        request(app)
            .put('/customers/d9d304e4e-8343-e4e768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 404 if the customer does not exist', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4ab4-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cb1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the order ID is not a valid UUID', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-2-aca0-')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The order ID is invalid');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 404 if the order does not exist', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673cd1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '404');
                assert.equal(res.body.message, 'No order with the specified ID exists');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if multiple required fields are missing', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1',
        "customer_id": 'd9d30b16-e215-4e4e-8343-e40052ae768c',
        "book_id": '6bc5-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the book_id is not a valid UUID', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": '',
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if a required field is empty', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
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

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '4a68abb2-8300-4192-8ef0-161db0584397',
        "customer_id": 'd9d30b16-e215-4e4e-8343-e40052ae768c',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the order_id field is modified', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The order ID can not be changed');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '0fdd2629-879b-40d1-8b18-4e6731121d7e',
        "customer_id": '5ede3fbd-a6e2-40ce-aca0-ed8fe6673cd1',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 400 if the customer_id field is modified', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The customer this order is associated with can not be changed');
                done();
            });
    });
});

describe('PUT /customers/{customer_id}/orders/{order_id}', function () {
    let data = {
        "order_id": '5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1',
        "customer_id": 'd9d30b16-e215-4e4e-8343-e40052ae768c',
        "book_id": '6bc5c1f8-bbc6-4e5b-a197-3081b7cfcd8b',
        "quantity": 1,
        "ship_date": '17/11/2019',
        "status": 'delivered',
        "complete": true
    }
    it('respond with 200 if all updates are valid', function (done) {
        request(app)
            .put('/customers/d9d30b16-e215-4e4e-8343-e40052ae768c/orders/5ede3fbd-a6e2-40ce-aca0-ed8fe6673ca1')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.orderDetails, 'object');
                assert.property(res.body.orderDetails, 'book_ids');
                assert.property(res.body.orderDetails, 'quantity');
                assert.property(res.body.orderDetails, 'status');
                assert.equal(res.body.orderDetails.ship_date, '17/11/2019');
                assert.equal(res.body.orderDetails.quantity, 1);
                done();
            });
    });
});
