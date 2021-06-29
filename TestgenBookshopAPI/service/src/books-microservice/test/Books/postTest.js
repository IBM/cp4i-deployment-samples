const request = require('supertest');
const assert = require('chai').assert;
const expect = require('chai').expect;
const app = require('../../app');

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "An Author",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "1234567890",
        "format": "digital"
    }
    it('respond with 401 if no authorization provided', function (done) {
        request(app)
            .post('/books')
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

describe('POST /books', function () {
    it('respond with 403 if the user is not an admin', function (done) {
        request(app)
            .post('/books')
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

describe('POST /books', function () {
    let data = "<html><body><h1>should reject html</h1></body></html>"
    it('respond with 415 if content-type is not json', function (done) {
        request(app)
            .post('/books')
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

describe('POST /books', function () {
    let data = {
        "title": "newBook",
    }
    it('respond with 400 Author is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Author is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "author": "newBook",
    }
    it('respond with 400 Title is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Title is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor"
    }
    it('respond with 400 Publisher is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'publisher is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher"
    }
    it('respond with 400 Date is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Date is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29"
    }
    it('respond with 400 isbn is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'ISBN is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "1234567890"
    }
    it('respond with 400 format is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'format is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "1234567890"
    }
    it('respond with 400 format is required', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'format is a required field');
                assert.equal(res.body.target.type, 'field')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "2",
        "format": "digital"
    }
    it('respond with 400 invalid ISBN length', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Invalid ISBN provided');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "ABEC34568@",
        "format": "digital"
    }
    it('respond with 400 ISBN should only contain number', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'ISBN must contain only numbers');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });
    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "1234567890",
        "format": "concrete"
    }
    it('respond with 400 invalid format provided', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Invalid value provided for format');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "newAuthor",
        "publisher": "newPublisher",
        "date": "2010-14-44",
        "isbn": "1234567890",
        "format": "digital"
    }
    it('respond with 400 invalid date provided', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'Date provided is not valid');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "Rob Author",
        "publisher": "newPublisher",
        "date": "2010-10-10",
        "isbn": "1234567890",
        "format": "digital"
    }
    it('respond with 400 the author is not recognized', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The author is unknown');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "ThisAuthor",
        "publisher": "newPublisher",
        "date": "2010-04-03",
        "isbn": "1234303890",
        "format": "digital"
    }
    it('respond with 400 the book is unavailable', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'The book is unavailable at this time');
                assert.equal(res.body.target.type, 'parameter')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "ThisAuthor",
        "publisher": "newPublisher",
        "date": "2010-10-03",
        "isbn": "1234392890",
        "format": "digital"
    }
    it('respond with 400 the book already exists', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(400)
            .end(function(error, res) {
                if (error) return done(error);
                assert.equal(res.body.code, '400');
                assert.equal(res.body.message, 'There is an existing book with the same ISBN');
                assert.equal(res.body.target.type, 'field')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "An Author",
        "publisher": "newPublisher",
        "date": "2009-11-29",
        "isbn": "1234567890",
        "format": "digital",
        "random-field": "RANDOM"
    }
    it('respond with 201 and ignore and additional fields not in the spec', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object')
                assert.notProperty(res.body.book, 'random-field')
                done();
            });

    });
});

describe('POST /books', function () {
    let data = {
        "title": "newBook",
        "author": "An Author",
        "publisher": "newPublisher",
        "date": "2010-10-28",
        "isbn": "1234567890",
        "format": "digital"
    }
    it('respond with 201 book created successfully', function (done) {
        request(app)
            .post('/books')
            .send(data)
            .set('Accept', 'application/json')
            .set('Authorization', process.env.ADMIN_AUTH)
            .expect('Content-Type', /json/)
            .expect(201)
            .end(function(error, res) {
                if (error) return done(error);
                assert.typeOf(res.body.book, 'object');
                const locationPresent = res.get('Location') === undefined;
                expect(locationPresent).to.be.false;
                done();
            });

    });
});