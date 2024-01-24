const request = require('supertest');
const assert = require('chai').assert;

const app = require('../../app');

describe('DELETE /books', function () {
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .delete('/books/cd46b818-e714-4e55-b978-1b9bb3afdc32')
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

describe('DELETE /books', function () {
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .delete('/books/cd46b818-e714-4e55-b978-1b9bb3afdc32')
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

describe('DELETE /books', function () {
    it('respond with 404 if the book can not be located', function (done) {
        request(app)
            .delete('/books/cd46b818-e714-4e55-b978-1b9bb3acdc32')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(404)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '404');
                assert.equal(res.body.message, 'The requested book was not found in the shop');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('DELETE /books', function () {
    it('respond with 400 if url book_id is not a valid UUID', function (done) {
        request(app)
            .delete('/books/cd46b818-e714-4e55')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The book ID is invalid');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('DELETE /books', function () {
    it('respond with 204 if book successfully deleted', function (done) {
        request(app)
            .delete('/books/6c7dbeb4-d75f-48da-b201-eecb85116fb6')
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect(204)
            .end(function(error, res) {
                if (error) return done(error);
                done();
            });
    });
});
