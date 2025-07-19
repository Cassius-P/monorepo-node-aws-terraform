import { Module } from '@nestjs/common';
import { HealthController } from './modules/health/health.controller';
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';
import { APP_GUARD } from '@nestjs/core';
import { ParrotModule } from './modules/parrot/parrot.module';

@Module({
  imports: [
    ParrotModule,
    ThrottlerModule.forRoot([
      {
        name: 'short',
        ttl: 60000, // 1 minute
        limit: 10, // 10 requests par minute
      },
      {
        name: 'medium',
        ttl: 300000, // 5 minutes
        limit: 50, // 50 requests par 5 minutes
      },
      {
        name: 'long',
        ttl: 3600000, // 1 heure
        limit: 100, // 100 requests par heure
      },
    ]),
  ],
  controllers: [HealthController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
  ],
})
export class AppModule {}