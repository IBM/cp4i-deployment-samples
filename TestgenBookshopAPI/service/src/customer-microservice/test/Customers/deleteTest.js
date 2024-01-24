const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');

describe('DELETE /customers/{customer_id}', function () {
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .delete('/customers/c3d75d675-1c61-4bce-8489-e4417ecfaafa')
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

describe('DELETE /customers/{customer_id}', function () {
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .delete('/customers/d5537670-bb0d-410f-adb9-cfcb04d02f06')
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

describe('DELETE /customers/{customer_id}', function () {
    it('respond with 400 if the customer id is not a valid UUID', function (done) {
        request(app)
            .delete('/customers/d5537-410f-adb9-')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The Customer ID is invalid');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('DELETE /customers/{customer_id}', function () {
    it('respond with 404 if the customer does not exist', function (done) {
        request(app)
            .delete('/customers/ed6875b1-1631-4916-a5f0-95fc295554ab')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '404');
                assert.equal(res.body.message, 'The customer could not be located');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('DELETE /customers/{customer_id}', function () {
    it('respond with 204 if the has been customer successfully deleted', function (done) {
        request(app)
            .delete('/customers/ed6875b1-1631-4916-a5f0-95fcc295554a')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(204)
            .end(function(error) {
                if (error) return done(error);
                done();
            });
    });
});