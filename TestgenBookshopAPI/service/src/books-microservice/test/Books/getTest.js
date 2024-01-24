const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');


describe('GET /books', function () {
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .get('/books/6c7dbeb4-d75f-48da-b201-eecb85116fb6')
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

describe('GET /books', function () {
    it('respond with 200 if the user is an admin', function (done) {
        request(app)
            .get('/books/6c7dbeb4-d75f-48da-b201-eecb85116fb6')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                done();
            });
    });
});

describe('GET /books', function () {
    it('respond with 200 if the user is not an admin', function (done) {
        request(app)
            .get('/books/6c7dbeb4-d75f-48da-b201-eecb85116fb6')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                done();
            });
    });
});

describe('GET /books', function () {
    it('respond with 400 invalid book ID', function (done) {
        request(app)
            .get('/books/123455848')
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

describe('GET /books', function () {
    it('respond with 400 book does not exist', function (done) {
        request(app)
            .get('/books/6c7dbeb4-d75f-48da-b201-eecb3ac16fb6')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
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

describe('GET /books', function () {
    it('respond with 200 book exists', function (done) {
        request(app)
            .get('/books/6c7dbeb4-d75f-48da-b201-eecb85116fb6')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.USER_AUTH)
            .expect('Content-Type', /json/)
            .expect(200)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                done();
            });
    });
});

