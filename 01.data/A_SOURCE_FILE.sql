
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[A_SOURCE_FILE](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[date] [datetime] NULL,
	[source] [nvarchar](255) NULL,
	[import_id] [int] NULL,
	[activity_id] [int] NULL,
	[forecast_id] [int] NULL,
	[domain] [nvarchar](250) NULL,
	[file_id] [int] NULL,
	[date_created] [datetime] NULL,
	[session] [nvarchar](50) NULL,
	[A] [nvarchar](255) NULL,
	[B] [nvarchar](255) NULL,
	[C] [nvarchar](255) NULL,
	[D] [nvarchar](255) NULL,
	[E] [nvarchar](255) NULL,
	[F] [nvarchar](255) NULL,
	[G] [nvarchar](255) NULL,
	[H] [nvarchar](255) NULL,
	[I] [nvarchar](255) NULL,
	[J] [nvarchar](255) NULL,
	[K] [nvarchar](255) NULL,
	[L] [nvarchar](255) NULL,
	[M] [nvarchar](255) NULL,
	[N] [nvarchar](255) NULL,
	[O] [nvarchar](255) NULL,
	[P] [nvarchar](255) NULL,
	[Q] [nvarchar](255) NULL,
	[R] [nvarchar](255) NULL,
	[S] [nvarchar](255) NULL,
	[T] [nvarchar](255) NULL,
	[U] [nvarchar](255) NULL,
	[V] [nvarchar](255) NULL,
	[W] [nvarchar](255) NULL,
	[X] [nvarchar](255) NULL,
	[Y] [nvarchar](255) NULL,
	[Z] [nvarchar](255) NULL,
	[AA] [nvarchar](255) NULL,
	[AB] [nvarchar](255) NULL,
	[AC] [nvarchar](255) NULL,
	[AD] [nvarchar](255) NULL,
	[AE] [nvarchar](255) NULL,
	[AF] [nvarchar](255) NULL,
	[AG] [nvarchar](255) NULL,
	[AH] [nvarchar](255) NULL,
	[AI] [nvarchar](255) NULL,
	[AJ] [nvarchar](255) NULL,
	[AK] [nvarchar](255) NULL,
	[AL] [nvarchar](255) NULL,
	[AM] [nvarchar](255) NULL,
	[AN] [nvarchar](255) NULL,
	[AO] [nvarchar](255) NULL,
	[AP] [nvarchar](255) NULL,
	[AQ] [nvarchar](255) NULL,
	[AR] [nvarchar](255) NULL,
	[AS] [nvarchar](255) NULL,
	[AT] [nvarchar](255) NULL,
	[AU] [nvarchar](255) NULL,
	[AV] [nvarchar](255) NULL,
	[AW] [nvarchar](255) NULL,
	[AX] [nvarchar](255) NULL,
	[AY] [nvarchar](255) NULL,
	[AZ] [nvarchar](255) NULL,
	[BA] [nvarchar](255) NULL,
	[BB] [nvarchar](255) NULL,
	[BC] [nvarchar](255) NULL,
	[BD] [nvarchar](255) NULL,
	[BE] [nvarchar](255) NULL,
	[BF] [nvarchar](255) NULL,
	[BG] [nvarchar](255) NULL,
	[BH] [nvarchar](255) NULL,
	[BI] [nvarchar](255) NULL,
	[BJ] [nvarchar](255) NULL,
	[BK] [nvarchar](255) NULL,
	[BL] [nvarchar](255) NULL,
	[BM] [nvarchar](255) NULL,
	[BN] [nvarchar](255) NULL,
	[BO] [nvarchar](255) NULL,
	[BP] [nvarchar](255) NULL,
	[BQ] [nvarchar](255) NULL,
	[BR] [nvarchar](255) NULL,
	[BS] [nvarchar](255) NULL,
	[BT] [nvarchar](255) NULL,
	[BU] [nvarchar](255) NULL,
	[BV] [nvarchar](255) NULL,
	[BW] [nvarchar](255) NULL,
	[BX] [nvarchar](255) NULL,
	[BY] [nvarchar](255) NULL,
	[BZ] [nvarchar](255) NULL,
	[site_id] [int] NULL,
 CONSTRAINT [PK_A_SOURCE_FILE] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[A_SOURCE_FILE] ADD  CONSTRAINT [DF_A_SOURCE_FILE_date_created]  DEFAULT (getdate()) FOR [date_created]
GO

ALTER TABLE [dbo].[A_SOURCE_FILE] ADD  CONSTRAINT [DF_A_SOURCE_FILE_site_id]  DEFAULT ((1)) FOR [site_id]
GO


