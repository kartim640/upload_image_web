from flask import Blueprint, render_template, request, redirect, flash, url_for, send_from_directory, current_app
from flask_login import login_required, current_user, login_user, logout_user
from .database_connection.db_config import db
from .database_connection.models import User, File
from .utils.file_utils import allowed_file
from werkzeug.utils import secure_filename
import uuid
import os

main = Blueprint('main', __name__)
auth = Blueprint('auth', __name__)

@auth.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form.get('username')
        email = request.form.get('email')
        password = request.form.get('password')

        if User.query.filter_by(username=username).first():
            flash('Username already exists')
            return redirect(url_for('auth.register'))

        if User.query.filter_by(email=email).first():
            flash('Email already registered')
            return redirect(url_for('auth.register'))

        user = User(username=username, email=email)
        user.set_password(password)

        db.session.add(user)
        db.session.commit()

        flash('Registration successful')
        return redirect(url_for('auth.login'))

    return render_template('register.html')

@auth.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        user = User.query.filter_by(username=request.form.get('username')).first()
        if user and user.check_password(request.form.get('password')):
            login_user(user)
            return redirect(url_for('main.index'))
        flash('Invalid username or password')
    return render_template('login.html')

@auth.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('auth.login'))

@main.route('/', methods=['GET', 'POST'])
@login_required
def index():
    if request.method == 'POST':
        if 'file' not in request.files:
            flash('No file part')
            return redirect(request.url)

        files = request.files.getlist('file')

        if not files:
            flash('No selected files')
            return redirect(request.url)

        for file in files:
            if allowed_file(file.filename):
                original_filename = secure_filename(file.filename)
                extension = original_filename.rsplit('.', 1)[1].lower()
                filename = f"{uuid.uuid4()}.{extension}"

                try:
                    file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], filename)
                    file.save(file_path)

                    file_record = File(
                        filename=filename,
                        original_filename=original_filename,
                        user_id=current_user.id
                    )
                    db.session.add(file_record)
                    db.session.commit()

                    flash(f'File {original_filename} successfully uploaded')

                except Exception as e:
                    flash(f'Error while saving file {original_filename}: {str(e)}')

            else:
                flash('Invalid file type. Please upload an image (jpg, jpeg, png, gif).')

        return redirect(url_for('main.index'))

    files = File.query.filter_by(user_id=current_user.id).order_by(File.upload_date.desc()).all()
    return render_template('index.html', files=files)

@main.route('/download/<int:file_id>')
@login_required
def download_file(file_id):
    file = File.query.get_or_404(file_id)
    if file.user_id != current_user.id:
        flash('Permission denied')
        return redirect(url_for('main.index'))

    file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], file.filename)
    if os.path.exists(file_path):
        return send_from_directory(current_app.config['UPLOAD_FOLDER'], file.filename, as_attachment=True)
    else:
        flash('File not found')
        return redirect(url_for('main.index'))

@main.route('/delete/<int:file_id>')
@login_required
def delete_file(file_id):
    file = File.query.get_or_404(file_id)
    if file.user_id != current_user.id:
        flash('Permission denied')
        return redirect(url_for('main.index'))

    file_path = os.path.join(current_app.config['UPLOAD_FOLDER'], file.filename)
    if os.path.exists(file_path):
        os.unlink(file_path)

    db.session.delete(file)
    db.session.commit()

    flash('File deleted successfully')
    return redirect(url_for('main.index'))

@main.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

@main.errorhandler(500)
def internal_server_error(e):
    return render_template('500.html'), 500