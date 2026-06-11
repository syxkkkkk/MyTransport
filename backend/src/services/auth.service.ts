import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../config/prisma';
import { env } from '../config/env';
import { ApiError } from '../utils/ApiError';
import type { RegisterBody, LoginBody } from '../validations/auth.schema';

function signAccessToken(payload: { sub: string; email: string; name: string }) {
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, { expiresIn: env.JWT_ACCESS_EXPIRES_IN } as jwt.SignOptions);
}

function signRefreshToken(userId: string) {
  return jwt.sign({ sub: userId }, env.JWT_REFRESH_SECRET, { expiresIn: env.JWT_REFRESH_EXPIRES_IN } as jwt.SignOptions);
}

export const AuthService = {
  async register(data: RegisterBody) {
    const existing = await prisma.user.findUnique({ where: { email: data.email } });
    if (existing) throw ApiError.conflict('Email is already registered');

    const passwordHash = await bcrypt.hash(data.password, 12);
    const user = await prisma.user.create({
      data: { email: data.email, name: data.name, passwordHash, phoneNumber: data.phoneNumber },
      select: { id: true, email: true, name: true, createdAt: true },
    });

    const accessToken = signAccessToken({ sub: user.id, email: user.email, name: user.name });
    const refreshToken = signRefreshToken(user.id);

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({ data: { token: refreshToken, userId: user.id, expiresAt } });

    return { user, accessToken, refreshToken };
  },

  async login(data: LoginBody) {
    const user = await prisma.user.findUnique({ where: { email: data.email } });
    if (!user) throw ApiError.unauthorized('Invalid email or password');

    const valid = await bcrypt.compare(data.password, user.passwordHash);
    if (!valid) throw ApiError.unauthorized('Invalid email or password');

    const accessToken = signAccessToken({ sub: user.id, email: user.email, name: user.name });
    const refreshToken = signRefreshToken(user.id);

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({ data: { token: refreshToken, userId: user.id, expiresAt } });

    const { passwordHash: _, ...safeUser } = user;
    return { user: safeUser, accessToken, refreshToken };
  },

  async refresh(token: string) {
    let payload: { sub: string };
    try {
      payload = jwt.verify(token, env.JWT_REFRESH_SECRET) as { sub: string };
    } catch {
      throw ApiError.unauthorized('Refresh token is invalid or expired');
    }

    const stored = await prisma.refreshToken.findUnique({ where: { token }, include: { user: true } });
    if (!stored || stored.expiresAt < new Date()) throw ApiError.unauthorized('Refresh token not found or expired');

    // Rotate token
    await prisma.refreshToken.delete({ where: { token } });

    const { user } = stored;
    const newAccessToken = signAccessToken({ sub: user.id, email: user.email, name: user.name });
    const newRefreshToken = signRefreshToken(user.id);
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await prisma.refreshToken.create({ data: { token: newRefreshToken, userId: user.id, expiresAt } });

    return { accessToken: newAccessToken, refreshToken: newRefreshToken };
  },

  async logout(token: string) {
    await prisma.refreshToken.deleteMany({ where: { token } });
  },

  async getProfile(userId: string) {
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, email: true, name: true, avatarUrl: true, phoneNumber: true, createdAt: true },
    });
    if (!user) throw ApiError.notFound('User');
    return user;
  },
};
